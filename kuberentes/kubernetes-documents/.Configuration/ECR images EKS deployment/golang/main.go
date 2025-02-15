package main

import (
	"net/http"
	"os"

	"github.com/gorilla/handlers"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", greetApiHandler)
	mux.HandleFunc("/health", healthApiHandler)
	http.ListenAndServe(":8080", handlers.CombinedLoggingHandler(os.Stdout, mux))
}

func healthApiHandler(w http.ResponseWriter, req *http.Request) {
	switch req.Method {
	case "GET":
		w.WriteHeader(200)
		w.Write([]byte("OK"))
	}
}

func greetApiHandler(w http.ResponseWriter, req *http.Request) {
	switch req.Method {
	case "GET":
		w.WriteHeader(200)
		w.Write([]byte("Hello World!"))
	}
}