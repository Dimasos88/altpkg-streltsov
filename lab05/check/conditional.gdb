set pagination off
set confirm off
break print_term if index == 2
commands
  silent
  printf "CHECK conditional %lu %ld\n", index, value
  backtrace 3
  continue
end
run 0 8 2 > /dev/null
