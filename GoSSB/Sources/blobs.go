package main

import "C"
import (
	"os"

	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/app/commands"
	"github.com/planetary-social/scuttlego/service/domain/refs"
)

//export ssbBlobsWant
func ssbBlobsWant(ref string) bool {
	defer logPanic()

	var err error
	defer logError("ssbBlobsWant", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return false
	}

	id, err := refs.NewBlob(ref)
	if err != nil {
		err = errors.Wrap(err, "could not create a ref")
		return false
	}

	cmd := commands.DownloadBlob{
		Id: id,
	}

	err = service.App.Commands.DownloadBlob.Handle(cmd)
	if err != nil {
		err = errors.Wrap(err, "command failed")
		return false
	}

	return true
}

//export ssbBlobsAdd
func ssbBlobsAdd(fd int32) *C.char {
	defer logPanic()

	var err error
	defer logError("ssbBlobsAdd", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return nil
	}

	cmd := commands.CreateBlob{
		Reader: os.NewFile(uintptr(fd), "newBlob"),
	}

	ref, err := service.App.Commands.CreateBlob.Handle(cmd)
	if err != nil {
		err = errors.Wrap(err, "command failed")
		return nil
	}

	// todo push blobs differently
	//err = sbot.WantManager.WantWithDist(br, -1)
	//if err != nil {
	//	err = errors.Wrap(err, "push: pushing blob to other peers failed")
	//	return nil
	//}

	return C.CString(ref.String())
}
