# Fixture: mirrors gdhd.be's sub-script propagation, success path.
var sub_err = run_file("good.be")
if sub_err != ""
  raise "load_error", sub_err
end
