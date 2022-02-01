// SPDX-License-Identifier: MIT

package ssb

import refs "go.mindeco.de/ssb-refs"

type Authorizer interface {
	Authorize(remote refs.FeedRef) error
}
