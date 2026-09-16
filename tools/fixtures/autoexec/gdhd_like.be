# Fixture: mirrors gdhd.be's sub-script error propagation (raises so
# autoexec's try/except in run_file records the real error).
var sub_err = run_file("boom.be")
if sub_err != ""
  raise "load_error", sub_err
end
