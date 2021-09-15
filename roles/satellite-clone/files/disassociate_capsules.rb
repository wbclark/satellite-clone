#!/usr/bin/ruby

require 'shellwords'
require 'rubygems'

@username = "admin"
@password = "changeme"

def prepare_hammer_cmd(command)
  "hammer -u #{@username.shellescape} -p #{@password.shellescape} #{command}"
end

def run_hammer_cmd(command)
  command = prepare_hammer_cmd(command)
  `#{command}`
end

def get_info_from_hammer(command, column=1)
  bash_parse = " | grep -v \"Warning:\" | tail -n+2 | awk -F, {'print $#{column}'}"
  run_hammer_cmd(command + bash_parse)
end

def capsule_lce_args(action, capsule_id, env)
  "--csv capsule content #{action}-lifecycle-environment --id #{capsule_id} --lifecycle-environment-id #{env}"
end

external_capsule_ids = get_info_from_hammer("--csv capsule list --search 'feature = \"Pulp Node\"'")
STDOUT.puts "There are no external capsules to disassociate." if external_capsule_ids.empty?

external_capsules = external_capsule_ids.split("\n").map do |id|
  { id: id, lifecycle_environments: get_info_from_hammer("--csv capsule content lifecycle-environments --id #{id}").split("\n") }
end

reverse_commands = external_capsules.map do |capsule|
  capsule[:lifecycle_environments].map do |env|
    run_hammer_cmd(capsule_lcs_args("remove", capsule[:id], env))
    prepare_hammer_cmd(capsule_lce_args("add", capsule[:id], env))
  end
end.flatten

unless reverse_commands.empty?
  STDOUT.puts "All Capsules are unassociated with any lifecycle environments. This is to avoid any syncing errors with your original Satellite " \
              "and any interference with existing infrastructure. To reverse these changes, run the following commands," \
              " making sure to replace the credentials with your own."
  reverse_commands.each { |command| STDOUT.puts command }
end
