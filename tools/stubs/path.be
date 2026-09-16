# Stub `path` module for offline tests: exists() by trying to open the file.
var m = module("path")
m.exists = def (f)
  try
    var fh = open(f, "r")
    fh.close()
    return true
  except ..
    return false
  end
end
return m
