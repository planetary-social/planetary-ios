# persist [![GoDoc](https://godoc.org/github.com/keks/persist?status.png)](http://godoc.org/github.com/keks/persist)
Persist loads and saves Go objects to files

## Usage

First get it:

```
go get github.com/keks/persist
```

Then save objects like this:

```
var conf Config
f, err := os.Create("./project.conf")
if err != nil {
	log.Faralln("failed opening the persistent file:", err)
}

if err = persist.Save(f, &conf); err != nil {
	log.Fatalln("failed to save config:", err)
}
```

And load them like this:


```
// f is still in scope

var conf Config
if err := persist.Load(f, &conf); err != nil {
	log.Fatalln("failed to load config:", err)
}
```
