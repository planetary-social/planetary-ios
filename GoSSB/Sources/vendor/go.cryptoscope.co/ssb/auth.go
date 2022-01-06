// SPDX-License-Identifier: MIT

package ssb

type Authorizer interface {
	Authorize(remote *FeedRef) error
}
