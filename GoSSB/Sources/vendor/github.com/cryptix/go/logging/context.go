package logging

import (
	"os"
	"context"
	"net/http"

	kitlog "github.com/go-kit/kit/log"
)

type logctxKeyT string

// LogCTXKey is the typed context key
var LogCTXKey logctxKeyT = "loggingContextKey"

// NewContext helps constructing and wrapping a logger into a context
func NewContext(ctx context.Context, log Interface) context.Context {
	return context.WithValue(ctx, LogCTXKey, log)
}

// FromContext extracts a logger from a context and casts to the log Interface
func FromContext(ctx context.Context) Interface {
	v, ok := ctx.Value(LogCTXKey).(Interface)
	if !ok {
		lw:=kitlog.NewSyncWriter(os.Stderr)
		fallback:=kitlog.NewLogfmtLogger(lw)
		return  kitlog.With(fallback, "warning", "no logger in context")
	}
	return v
}

// InjectHandler injects a log instance to http.Request' context
func InjectHandler(mainLog Interface) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			ctx := req.Context()
			if l := FromContext(ctx); l == nil {
				l = kitlog.With(mainLog, "urlPath", req.URL.Path)
				req = req.WithContext(NewContext(ctx, l))
			}
			next.ServeHTTP(w, req)
		})
	}
}
