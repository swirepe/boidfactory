package generator

import (
    "crypto/sha1"
    "encoding/binary"
    "fmt"
    "encoding/json"
    "math/rand/v2"
    "strings"
    "time"
)

//go:generate echo "templates embedded via go:embed in template.go"

type Config struct {
    Count       int
    Vision      float64
    Sep         float64
    MaxSpeed    float64
    MinSpeed    float64
    MaxForce    float64
    AlignW      float64
    CohesionW   float64
    SeparationW float64
    LineWidth   float64
    Wrap        bool
}

func defaultConfig(r *rand.Rand) Config {
    return Config{
        Count:       220 + r.IntN(120),
        Vision:      65 + r.Float64()*45,
        Sep:         18 + r.Float64()*10,
        MaxSpeed:    2.0 + r.Float64()*1.8,
        MinSpeed:    0.6 + r.Float64()*0.6,
        MaxForce:    0.05 + r.Float64()*0.05,
        AlignW:      0.8 + r.Float64()*0.8,
        CohesionW:   0.6 + r.Float64()*0.8,
        SeparationW: 1.0 + r.Float64()*1.5,
        LineWidth:   1.1 + r.Float64()*0.9,
        Wrap:        r.IntN(2) == 0,
    }
}

func seedFromString(s string) uint64 {
    if s == "" {
        return uint64(time.Now().UnixNano())
    }
    h := sha1.Sum([]byte(s))
    return binary.LittleEndian.Uint64(h[:8])
}

// GenerateFromSeed returns the single-file HTML using a deterministic seed string.
func GenerateFromSeed(seedStr string) (string, error) {
    seed := seedFromString(seedStr)
    r := rand.New(rand.NewPCG(uint64(seed>>1), uint64(seed<<1)|1))
    cfg := defaultConfig(r)
    hue := int(r.IntN(360))
    title := fmt.Sprintf("Boids (Go) · N=%d · hue=%d", cfg.Count, hue)
    data := map[string]any{
        "Title":       title,
        "DefaultHue":  hue,
        "Seed":        seed,
        "Header":      "Boids — Go generator",
        "Subheader":   "Single-file canvas · alignment/cohesion/separation",
        "CfgCount":    cfg.Count,
        "CfgVision":   cfg.Vision,
        "CfgSep":      cfg.Sep,
        "CfgMaxSpeed": cfg.MaxSpeed,
        "CfgMinSpeed": cfg.MinSpeed,
        "CfgMaxForce": cfg.MaxForce,
        "CfgAlignW":   cfg.AlignW,
        "CfgCohW":     cfg.CohesionW,
        "CfgSepW":     cfg.SeparationW,
        "CfgLineW":    cfg.LineWidth,
        "CfgWrap":     cfg.Wrap,
    }
    return executeTemplate(pageTemplate, data)
}

// WriteFile writes a generated HTML to the folder. When idx is nil, it uses the non-indexed name.
func WriteFile(folder string, idx *int) (string, error) {
    name := "boids-dod-quadtree-impl.html"
    if idx != nil {
        name = fmt.Sprintf("boids-dod-quadtree-%d-impl.html", *idx)
    }
    full := folder + "/" + name
    stamp := time.Now().UnixNano()
    html, err := GenerateFromSeed(fmt.Sprintf("%d/%s", stamp, name))
    if err != nil { return "", err }
    return full, osWriteFile(full, []byte(html), 0o644)
}

func executeTemplate(tpl string, data map[string]any) (string, error) {
    // Simple string replacement to avoid bringing in text/template escaping rules for inline JS
    // Placeholders are of the form {{Name}}
    out := tpl
    repl := func(k string, v string) { out = strings.ReplaceAll(out, "{{"+k+"}}", v) }
    // string/int conversions
    repl("Title", fmt.Sprint(data["Title"]))
    repl("DefaultHue", fmt.Sprint(data["DefaultHue"]))
    repl("Seed", fmt.Sprint(data["Seed"]))
    // JSON-quote header strings for safe JS injection
    repl("HEADER_JSON", jsonQuote(fmt.Sprint(data["Header"])))
    repl("SUBHEADER_JSON", jsonQuote(fmt.Sprint(data["Subheader"])))
    repl("CfgCount", fmt.Sprint(data["CfgCount"]))
    repl("CfgVision", fmt.Sprint(data["CfgVision"]))
    repl("CfgSep", fmt.Sprint(data["CfgSep"]))
    repl("CfgMaxSpeed", fmt.Sprint(data["CfgMaxSpeed"]))
    repl("CfgMinSpeed", fmt.Sprint(data["CfgMinSpeed"]))
    repl("CfgMaxForce", fmt.Sprint(data["CfgMaxForce"]))
    repl("CfgAlignW", fmt.Sprint(data["CfgAlignW"]))
    repl("CfgCohW", fmt.Sprint(data["CfgCohW"]))
    repl("CfgSepW", fmt.Sprint(data["CfgSepW"]))
    repl("CfgLineW", fmt.Sprint(data["CfgLineW"]))
    if data["CfgWrap"].(bool) { repl("CfgWrap", "true") } else { repl("CfgWrap", "false") }
    return out, nil
}

func jsonQuote(s string) string {
    // Minimal JSON quoting using stdlib encoding/json
    b, _ := json.Marshal(s)
    return string(b)
}

// tiny wrapper to keep imports local to file
func osWriteFile(name string, data []byte, perm uint32) error {
    return realWriteFile(name, data, perm)
}
