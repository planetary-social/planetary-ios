package main

import (
	"fmt"
	refs "go.mindeco.de/ssb-refs"
	"io"
	"os"
	"strconv"

	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
)

import "C"

//export ssbBlobsWant
func ssbBlobsWant(ref string) bool {
	defer logPanic()

	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("where", "blobsWant", "error", err)
		}
	}()

	lock.Lock()
	if sbot == nil {
		err = ErrNotInitialized
		lock.Unlock()
		return false
	}
	lock.Unlock()

	br, err := refs.ParseBlobRef(ref)
	if err != nil {
		err = errors.Wrap(err, "want: invalid argument")
		return false
	}
	if _, err := sbot.BlobStore.Get(br); err == nil {
		return true
	}
	err = sbot.WantManager.Want(br)
	if err != nil {
		err = errors.Wrap(err, "want: wanting failed")
		return false
	}
	return true
}

//export ssbBlobsGet
func ssbBlobsGet(ref string) int {
	defer logPanic()

	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("ssbBlobsGet", err)
		}
	}()

	lock.Lock()
	if sbot == nil {
		err = ErrNotInitialized
		lock.Unlock()
		return -1
	}
	lock.Unlock()
	level.Warn(log).Log("deprecated", "ssbBlobsGet", "msg", "this uses os pipe - use direct file system access to get a blob")

	br, err := refs.ParseBlobRef(ref)
	if err != nil {
		err = errors.Wrap(err, "blobs/get: invalid blob ref")
		return -1
	}
	blobReader, err := sbot.BlobStore.Get(br)
	if err != nil {
		err = errors.Wrap(err, "blobs/get: store get failed")
		return -1
	}

	r, w, err := os.Pipe()
	if err != nil {
		err = errors.Wrap(err, "pipe: creation failed")
		return -1
	}

	fdptr := r.Fd()
	fd, err := strconv.Atoi(fmt.Sprint(fdptr))
	if err != nil {
		err = errors.Wrap(err, "pipe: failed to extract FD")
		return -1
	}

	go func() {
		_, err = io.Copy(w, blobReader)
		if err != nil {
			err = errors.Wrap(err, "blobs/get: transfer failed")
		}
		w.Close()
	}()

	return fd
}

//export ssbBlobsAdd
func ssbBlobsAdd(fd int32) *C.char {
	defer logPanic()

	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("ssbBlobsAdd", err)
		}
	}()

	lock.Lock()
	if sbot == nil {
		err = ErrNotInitialized
		lock.Unlock()
		return nil
	}
	lock.Unlock()

	f := os.NewFile(uintptr(fd), "newBlob")

	br, err := sbot.BlobStore.Put(f)
	if err != nil {
		err = errors.Wrap(err, "blobs/add: put failed")
		return nil
	}
	f.Close()

	return C.CString(br.String())
}

//export ssbPushBlobToAllPeers
func ssbPushBlobToAllPeers(ref string) bool {
	defer logPanic()

	var err error
	defer func() {
		if err != nil {
			level.Error(log).Log("where", "ssbPushBlobToAllPeers", "error", err)
		}
	}()

	lock.Lock()
	if sbot == nil {
		err = ErrNotInitialized
		lock.Unlock()
		return false
	}
	lock.Unlock()

	br, err := refs.ParseBlobRef(ref)
	if err != nil {
		err = errors.Wrap(err, "could not parse blob ref")
		return false
	}

	sbot.WantManager.PushBlob(br)

	return true
}
