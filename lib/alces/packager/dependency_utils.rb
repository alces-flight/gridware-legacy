require 'yaml'
require 'aw'

module Alces
  module Packager
    class DependencyUtils

      class << self

        delegate :warning, :to => IoHandler

        def generate_dependency_script(package, phase)
          %(#!/bin/bash
set -x
#=Alces-Gridware-Dependencies:3
if [ $UID -ne 0 ]; then
  SUDO="sudo -E "
fi
if [ "${flight_ROOT}" ]; then
  executor="${flight_ROOT}/bin/flexec ruby "
fi
${SUDO}${executor}#{ENV['flight_GRIDWARE_root']}/bin/gridware dependencies #{strip_variant(package.path)} --phase #{phase} --non-interactive --trace)
        end

        def generate_legacy_dependency_script(package, phase)
          deps_hashes = [].tap do |a|
            if package.metadata[:dependencies][phase]
              a << package.metadata[:dependencies][phase]
              if phase == :build && package.metadata[:dependencies].key?(:runtime)
                a << package.metadata[:dependencies][:runtime]
              end
            else
              a << package.metadata[:dependencies]
            end
          end
          deps = deps_hashes.map do |deps_hash|
            [*deps_hash[stem]] + [*deps_hash[ENV['cw_DIST']]]
          end.flatten
          unless deps.empty?
            s = %(deps=()\n)
            deps.each do |dep|
              s << %(if ! #{sprintf(check_command,dep)} >/dev/null; then\n  deps+=(#{dep})\nfi\n)
            end
            s << %(
if [ "${#deps[@]}" -gt 0 ]; then
  n=0
  for a in "${deps[@]}"; do
    n=$(($n+1))
    echo -n "Installing distro dependency ($n/${#deps[@]}): ${a} ..."
    c=0
    while ! #{sprintf(available_command,'"${a}"')}; do
      c=$(($c+1))
      if [ $c -gt 5 ]; then
        available_failed=true
        break
      fi
    done
    if [ -z "$available_failed" ]; then
  c=0
      while ! #{sprintf(install_command,'"${a}"')}; do
        c=$(($c+1))
        if [ $c -gt 5 ]; then
          echo ' FAILED'
          exit 1
        fi
      done
      echo ' OK'
    else
      echo ' NOT FOUND'
      exit 1
    fi
  done
fi)
            s
          end
        end

        def whitelist
          @whitelist ||= empty_whitelist.merge(whitelist_from_file)
        end

        def whitelist_package(pkg)
          my_wl = whitelist

          return whitelist if my_wl[:packages].include?(pkg)

          my_wl[:packages] << pkg
          File.open(whitelist_file, 'w') do |wf|
            wf.write(my_wl.to_yaml)
          end

          @whitelist = my_wl
        end

        def install_command
          case cw_dist
            when /^el/
              "env -i /usr/bin/yum install -y %s >>#{Config.log_root}/depends.log 2>&1"
            when /^ubuntu/
              "/usr/bin/apt-get install -y %s >>#{Config.log_root}/depends.log 2>&1"
          end
        end

        def check_command
          case cw_dist
            when /^el/
              'rpm -q %s >/dev/null 2>/dev/null'
            when /^ubuntu/
              'dpkg -l %s >/dev/null 2>/dev/null'
          end
        end

        def available_command
          case cw_dist
            when /^el/
              'env -i yum info %s >/dev/null 2>/dev/null'
            when /^ubuntu/
              'apt-cache show %s >/dev/null 2>/dev/null'
          end
        end

        def install_request_command
          "#{File.join(ENV['cw_ROOT'], 'libexec', 'share', 'distro-deps-notify')} \"%s\" \"%s\" \"%s\" \"%s\""
        end

        def stem
          case cw_dist
            when /^el/
              'el'
            when /^ubuntu/
              'ubuntu'
          end
        end

        def cw_dist
          @cw_dist ||= if !ENV['cw_DIST']
                         warning 'cw_DIST environment variable not set, defaulting to el7'
                         'el7'
                       else
                         ENV['cw_DIST']
                       end
        end

        private

        def strip_variant(package_path)
          # In the second-to-last component of the path (e.g. allow _ in version)
          # remove _ and everything subsequent up until the next /
          # This assumes we always get a full package path including version...
          package_path.gsub(/_[^\/]+(\/[^\/]+)$/, '\1')
        end

        def whitelist_from_file
          YAML.load_file(whitelist_file) rescue {}
        end

        def whitelist_file
          Alces::Tools::Config.find('whitelist',false) ||
            File.join(ENV.fetch('flight_ENV_dir', Config.gridware),'etc','whitelist.yml')
        end

        def empty_whitelist
          { users: [], packages: [], repos: [] }
        end

      end
    end
  end
end
