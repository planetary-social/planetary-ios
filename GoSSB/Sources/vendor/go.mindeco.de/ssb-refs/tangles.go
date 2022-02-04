package refs

import (
	"math"
	"sort"
	"sync"
)

// TangledPost is a utility type for ByPrevious' sorting functionality.
type TangledPost interface {
	Key() MessageRef

	Tangle(name string) (root *MessageRef, prev MessageRefs)
}

// ByPrevious offers sorting messages by their previous cipherlinks relation.
// See https://github.com/ssbc/ssb-sort for more.
type ByPrevious struct {
	TangleName string

	Items []TangledPost

	doFill sync.Once

	root  string
	after pointsToMap // message points to another (by previous field)
	backl pointsToMap // these messages point to another (reverse from the above)
}

func (m pointsToMap) add(k, msg MessageRef) {
	refs := m[k.String()]
	m[k.String()] = append(refs, msg.String())
}

// Heads on a sorted slice of messages returns a slice of message refs which are not referenced by any other.
// Need to call FillLookup() before using this.
func (by *ByPrevious) Heads() MessageRefs {
	by.doFill.Do(by.fillLookup)

	var r MessageRefs
	for _, i := range by.Items {
		if _, has := by.backl[i.Key().String()]; !has {
			r = append(r, i.Key())
		}
	}

	return r
}

type pointsToMap map[string][]string

func (by *ByPrevious) fillLookup() {
	after := make(pointsToMap, len(by.Items))
	backl := make(pointsToMap, len(by.Items))

	for _, m := range by.Items {
		root, prev := m.Tangle(by.TangleName)

		if root == nil || len(prev) == 0 {
			if by.root != "" {
				panic("root already set")
			}
			by.root = m.Key().String()
			continue
		}

		var refs = make([]string, len(prev))
		for j, br := range prev {
			refs[j] = br.String()

			// backlink
			backl.add(br, m.Key())
		}
		after[m.Key().String()] = refs
	}

	by.after = after
	by.backl = backl
}

// Len returns the number of messages, for sort.Sort.
func (by *ByPrevious) Len() int {
	by.doFill.Do(by.fillLookup)
	return len(by.Items)
}

func (by ByPrevious) currentIndex(key string) int {
	for idxBr, findBr := range by.Items {
		if findBr.Key().String() == key {
			return idxBr
		}
	}
	return -1
}

func (by ByPrevious) pointsTo(x, y string) bool {
	pointsTo, has := by.after[x]
	if !has {
		return false
	}

	for _, candidate := range pointsTo {
		if candidate == y {
			return true
		}
		if by.pointsTo(candidate, y) {
			return true
		}
	}
	return false
}

func (by ByPrevious) hopsToRoot(key string, hop int) int {
	if key == by.root {
		return hop
	}

	pointsTo, ok := by.after[key]
	if !ok {
		return math.MaxInt32 // we might not have the message
	}

	var found []int // collect all paths for tie-breaking
	for _, candidate := range pointsTo {
		if candidate == by.root {
			found = append(found, hop+1)
			continue
		}

		if h := by.hopsToRoot(candidate, hop+1); h > 0 {
			// TODO: fill up cache of these results
			found = append(found, h)
		}
	}

	if len(found) < 1 {
		panic("not pointing to root?")
	}
	sort.Ints(found)
	return found[len(found)-1]
}

// Less decides if message i is before j by looking up how many hops it takes from them to the root.
// TODO: tiebraker
func (by *ByPrevious) Less(i int, j int) bool {
	msgI, msgJ := by.Items[i], by.Items[j]
	keyI, keyJ := msgI.Key().String(), msgJ.Key().String()

	if by.pointsTo(keyI, keyJ) {
		return false
	}

	hopsI, hopsJ := by.hopsToRoot(keyI, 0), by.hopsToRoot(keyJ, 0)
	if hopsI < hopsJ {
		return true
	}

	return false
}

// Swap switches the two items (for sort.Sort)
func (by *ByPrevious) Swap(i int, j int) {
	by.Items[i], by.Items[j] = by.Items[j], by.Items[i]
}
