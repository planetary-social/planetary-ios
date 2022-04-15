package main

import "C"
import (
	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/app/commands"
)

//export ssbPublish
func ssbPublish(content string) *C.char {
	var err error
	defer logError("ssbPublish", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return nil
	}

	cmd := commands.PublishRaw{
		Content: []byte(content),
	}

	id, err := service.App.Commands.PublishRaw.Handle(cmd)
	if err != nil {
		err = errors.Wrap(err, "command failed")
		return nil
	}

	return C.CString(id.String())
}

//export ssbPublishPrivate
func ssbPublishPrivate(content, recps string) *C.char {
	return nil
}
