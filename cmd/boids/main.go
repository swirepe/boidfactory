package main

import (
    "flag"
    "fmt"
    "log"
    "net/http"
    "os"
    "path/filepath"
    "strings"
    "time"

    "boidfactory/local/internal/generator"
    "os/exec"
)

func main() {
    // Shared flags
    outDir := flag.String("out-dir", "", "Output directory (defaults to runs/boids-<timestamp>_singlefile)")
    count := flag.Int("count", 1, "Number of simulations to generate")
    buildIndex := flag.Bool("index", false, "Build a link viewer index.html in the output folder")

    // Server flags
    serve := flag.Bool("serve", false, "Run as HTTP server instead of generating files")
    addr := flag.String("addr", ":8080", "Address to listen on in server mode")

    flag.Parse()

    if *serve {
        runServer(*addr)
        return
    }

    // CLI generation mode (parity with agents/boids-singlefile-generator.py)
    folder := outDirPath(*outDir)
    var created []string
    for i := 1; i <= max(1, *count); i++ {
        var idx *int
        if *count > 1 {
            ii := i
            idx = &ii
        }
        path, err := generator.WriteFile(folder, idx)
        if err != nil {
            log.Fatalf("write failed: %v", err)
        }
        created = append(created, path)
    }

    fmt.Println("Created:")
    for _, p := range created {
        fmt.Println(" -", p)
    }
    fmt.Println("\nOpen in your browser and try:")
    fmt.Println("  ?hue=210&header=Hello&subheader=Go+generator")

    if *buildIndex {
        // If the helper exists, call it to build an index.html viewer.
        if _, err := os.Stat("build-link-viewer.sh"); err == nil {
            if err := runIndexBuilder(folder); err != nil {
                log.Printf("Failed to build link viewer: %v", err)
            } else {
                fmt.Printf("\nBuilt index.html for %s\n", folder)
            }
        } else {
            log.Printf("build-link-viewer.sh not found; skipping index build")
        }
    }
}

func outDirPath(custom string) string {
    if custom != "" {
        _ = os.MkdirAll(custom, 0o755)
        return custom
    }
    stamp := time.Now().Format("20060102_150405")
    p := filepath.Join("runs", fmt.Sprintf("boids-%s_singlefile", stamp))
    _ = os.MkdirAll(p, 0o755)
    return p
}

func max(a, b int) int { if a > b { return a }; return b }

func runIndexBuilder(folder string) error {
    // Best-effort: call the local Python viewer builder if available.
    // Avoids network; uses stdlib to spawn.
    return execPythonIndex(folder)
}

func execPythonIndex(folder string) error {
    cmd := exec.Command("python3", "build-link-viewer.sh", folder)
    return cmd.Run()
}

func runServer(addr string) {
    mux := http.NewServeMux()
    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        path := strings.Trim(r.URL.Path, "/")
        if path == "" || path == "favicon.ico" {
            path = "home"
        }
        // Seed from path; produce deterministic variant
        // Also set default header to the path, and leave subheader empty unless explicitly set by URL params.
        html, err := generator.Generate(path, path, "")
        if err != nil {
            http.Error(w, "generation error", 500)
            return
        }
        w.Header().Set("Content-Type", "text/html; charset=utf-8")
        _, _ = w.Write([]byte(html))
    })
    log.Printf("Serving boids at %s (GET /{seed})", addr)
    if err := http.ListenAndServe(addr, mux); err != nil {
        log.Fatal(err)
    }
}
