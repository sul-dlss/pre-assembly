#!/usr/bin/env ruby

@base_path = '/home/lyberadmin/jlavigne/BnF/update/'

#############################
def get_pid_to_file(pf_file)
############################

  if pf_file !~ /@base_path/
    pf_file = @base_path + pf_file
  end

  pf_lines = IO.readlines(pf_file).map { |x| x.chomp }

  pid_to_file = Hash.new
  pf_lines.each do |l|
    pid, file = l.split(/,/)
    pid_to_file[pid] = file
  end

  return pid_to_file

end # get_pid_to_file

#########
def main()
#########

  pid_to_file = get_pid_to_file(ARGV[0])  

  puts pid_to_file.inspect

end

main()




