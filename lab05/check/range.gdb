set pagination off
set confirm off
break print_term if index >= 1 && index <= 3
commands
  silent
  printf "CHECK range %lu %ld\n", index, value
  continue
end
run 0 8 2 > /dev/null
