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
    // Visual and behavior extensions
    TrailAlpha  float64
    BgGradient  bool
    BgHueShift1 int
    BgHueShift2 int
    BgHueShift3 int
    Qt          bool
    QtCap       int
    Flow        bool
    FlowAmp     float64
    FlowScale   float64
    FlowSpeed   float64
    // Visualization of the flow field
    FlowViz     bool
    FlowVizStep int
    // Advanced flow configuration
    FlowMode    string  // angle | curl | turbulence
    FlowAmpVar  float64 // 0..1 amplitude variation
    FlowAniso   float64 // -0.9..3 anisotropy factor on Y scale
    FlowOctaves int     // for turbulence
    // Flow-driven coloring
    FlowColor     bool
    FlowHueScale  float64 // 0..180 degrees of influence
    FlowColorMode string  // angle | strength
    FlowGlow      bool    // glow using nearest flow arrow hue
    // Overlay visibility
    ShowHeader     bool
    ShowSubheader  bool
    ShowHud     bool
    // Interaction variety
    ClickMode   string // shockwave | gravity | spin | scatter
    DragMode    string // pull | push | spin | flow
    // Vision visualization
    VisionViz   string // off | one | all
    Shape       string
    Blend       string
    Spawn       string
}

func defaultConfig(r *rand.Rand) Config {
    // Random but sane defaults for more variety
    shapes := []string{"trail","triangle","dot","comet","ring"}
    blends := []string{"lighter","plus-lighter","screen","source-over"}
    spawns := []string{"random","ring","center","edge","grid"}
    flow := r.IntN(100) < 50
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
        TrailAlpha:  0.08 + r.Float64()*0.12,
        BgGradient:  r.IntN(100) < 85,
        BgHueShift1: r.IntN(45),
        BgHueShift2: 30 + r.IntN(150),
        BgHueShift3: 60 + r.IntN(220),
        Qt:          true,
        QtCap:       10 + r.IntN(20),
        Flow:        flow,
        FlowAmp:     0.15 + r.Float64()*0.5,
        FlowScale:   0.001 + r.Float64()*0.006,
        FlowSpeed:   0.4 + r.Float64()*1.0,
        FlowViz:     flow, // show viz if flow is on
        FlowVizStep: 56 + r.IntN(40),
        FlowMode:    []string{"angle","curl","turbulence"}[r.IntN(3)],
        FlowAmpVar:  r.Float64()*0.5,
        FlowAniso:   (r.Float64()*0.6) - 0.2, // slightly anisotropic by default
        FlowOctaves: 1 + r.IntN(4),
        FlowColor:   true,
        FlowHueScale: 40 + r.Float64()*80, // 40..120 deg
        FlowColorMode: []string{"angle","strength"}[r.IntN(2)],
        FlowGlow:    flow, // default glow when viz likely on
        ShowHeader:  true,
        ShowSubheader: true,
        ShowHud:     true,
        ClickMode:   []string{"shockwave","gravity","spin","scatter"}[r.IntN(4)],
        DragMode:    []string{"pull","push","spin","flow"}[r.IntN(4)],
        VisionViz:   []string{"off","one","all"}[r.IntN(3)],
        Shape:       shapes[r.IntN(len(shapes))],
        Blend:       blends[r.IntN(len(blends))],
        Spawn:       spawns[r.IntN(len(spawns))],
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
func Generate(seedStr, header, subheader string) (string, error) {
    seed := seedFromString(seedStr)
    r := rand.New(rand.NewPCG(uint64(seed>>1), uint64(seed<<1)|1))
    cfg := defaultConfig(r)
    hue := int(r.IntN(360))
    title := fmt.Sprintf("Boids (Go) · N=%d · hue=%d", cfg.Count, hue)
    if header == "" { header = "Boids — Go generator" }
    // If subheader empty, leave it empty by default. Only show when explicitly set via URL or caller.
    data := map[string]any{
        "Title":       title,
        "DefaultHue":  hue,
        "Seed":        seed,
        "Header":      header,
        "Subheader":   subheader,
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
        "CfgTrailAlpha": cfg.TrailAlpha,
        "CfgBgGradient": cfg.BgGradient,
        "CfgBgHueShift1": cfg.BgHueShift1,
        "CfgBgHueShift2": cfg.BgHueShift2,
        "CfgBgHueShift3": cfg.BgHueShift3,
        "CfgQt":        cfg.Qt,
        "CfgQtCap":     cfg.QtCap,
        "CfgFlow":      cfg.Flow,
        "CfgFlowAmp":   cfg.FlowAmp,
        "CfgFlowScale": cfg.FlowScale,
        "CfgFlowSpeed": cfg.FlowSpeed,
        "CfgFlowViz":   cfg.FlowViz,
        "CfgFlowVizStep": cfg.FlowVizStep,
        "CfgFlowMode":   cfg.FlowMode,
        "CfgFlowAmpVar": cfg.FlowAmpVar,
        "CfgFlowAniso":  cfg.FlowAniso,
        "CfgFlowOctaves": cfg.FlowOctaves,
        "CfgFlowColor":  cfg.FlowColor,
        "CfgFlowHueScale": cfg.FlowHueScale,
        "CfgFlowColorMode": cfg.FlowColorMode,
        "CfgFlowGlow":   cfg.FlowGlow,
        "CfgShowHeader":  cfg.ShowHeader,
        "CfgShowSubheader": cfg.ShowSubheader,
        "CfgShowHud":   cfg.ShowHud,
        "CfgClickMode": cfg.ClickMode,
        "CfgDragMode":  cfg.DragMode,
        "CfgVisionViz": cfg.VisionViz,
        "CfgShape":     cfg.Shape,
        "CfgBlend":     cfg.Blend,
        "CfgSpawn":     cfg.Spawn,
    }
    return executeTemplate(pageTemplate, data)
}

func GenerateFromSeed(seedStr string) (string, error) {
    return Generate(seedStr, "", "")
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
    // Extended fields
    repl("CfgTrailAlpha", fmt.Sprint(data["CfgTrailAlpha"]))
    repl("CfgBgHueShift1", fmt.Sprint(data["CfgBgHueShift1"]))
    repl("CfgBgHueShift2", fmt.Sprint(data["CfgBgHueShift2"]))
    repl("CfgBgHueShift3", fmt.Sprint(data["CfgBgHueShift3"]))
    repl("CfgQtCap", fmt.Sprint(data["CfgQtCap"]))
    repl("CfgFlowAmp", fmt.Sprint(data["CfgFlowAmp"]))
    repl("CfgFlowScale", fmt.Sprint(data["CfgFlowScale"]))
    repl("CfgFlowSpeed", fmt.Sprint(data["CfgFlowSpeed"]))
    repl("CfgFlowVizStep", fmt.Sprint(data["CfgFlowVizStep"]))
    repl("CfgFlowMode", fmt.Sprint(data["CfgFlowMode"]))
    repl("CfgFlowAmpVar", fmt.Sprint(data["CfgFlowAmpVar"]))
    repl("CfgFlowAniso", fmt.Sprint(data["CfgFlowAniso"]))
    repl("CfgFlowOctaves", fmt.Sprint(data["CfgFlowOctaves"]))
    repl("CfgFlowHueScale", fmt.Sprint(data["CfgFlowHueScale"]))
    repl("CfgFlowColorMode", fmt.Sprint(data["CfgFlowColorMode"]))
    repl("CfgClickMode", fmt.Sprint(data["CfgClickMode"]))
    repl("CfgDragMode", fmt.Sprint(data["CfgDragMode"]))
    repl("CfgVisionViz", fmt.Sprint(data["CfgVisionViz"]))
    repl("CfgShape", fmt.Sprint(data["CfgShape"]))
    repl("CfgBlend", fmt.Sprint(data["CfgBlend"]))
    repl("CfgSpawn", fmt.Sprint(data["CfgSpawn"]))
    // booleans
    if data["CfgWrap"].(bool) { repl("CfgWrap", "true") } else { repl("CfgWrap", "false") }
    if data["CfgBgGradient"].(bool) { repl("CfgBgGradient", "true") } else { repl("CfgBgGradient", "false") }
    if data["CfgQt"].(bool) { repl("CfgQt", "true") } else { repl("CfgQt", "false") }
    if data["CfgFlow"].(bool) { repl("CfgFlow", "true") } else { repl("CfgFlow", "false") }
    if data["CfgFlowViz"].(bool) { repl("CfgFlowViz", "true") } else { repl("CfgFlowViz", "false") }
    if data["CfgFlowColor"].(bool) { repl("CfgFlowColor", "true") } else { repl("CfgFlowColor", "false") }
    if data["CfgFlowGlow"].(bool) { repl("CfgFlowGlow", "true") } else { repl("CfgFlowGlow", "false") }
    if data["CfgShowHeader"].(bool) { repl("CfgShowHeader", "true") } else { repl("CfgShowHeader", "false") }
    if data["CfgShowSubheader"].(bool) { repl("CfgShowSubheader", "true") } else { repl("CfgShowSubheader", "false") }
    if data["CfgShowHud"].(bool) { repl("CfgShowHud", "true") } else { repl("CfgShowHud", "false") }
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
