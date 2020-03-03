module go.cryptoscope.co/secretstream

require (
	github.com/cryptix/go v1.5.0
	github.com/go-kit/kit v0.9.0 // indirect
	github.com/stretchr/testify v1.4.0
	go.cryptoscope.co/netwrap v0.1.0
	golang.org/x/crypto v0.0.0-20200303113948-2939d6771b24
	golang.org/x/sys v0.0.0-20191007154456-ef33b2fb2c41 // indirect
)

go 1.13

replace golang.org/x/crypto => github.com/cryptix/golang_x_crypto v0.0.0-20200303113948-2939d6771b24
