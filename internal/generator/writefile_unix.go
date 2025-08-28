package generator

import (
    "os"
)

func realWriteFile(name string, data []byte, perm uint32) error {
    return os.WriteFile(name, data, os.FileMode(perm))
}

