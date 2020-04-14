#==============================================================================
# Copyright (C) 2020 Alces Flight Ltd.
#
# This file/package is part of Flight Gridware.
#
# Flight Gridware is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# Flight Gridware is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this package.  If not, see <http://www.gnu.org/licenses/>.
#
# For more information on the Flight Gridware, please visit:
# https://github.com/alces-flight/gridware-legacy
#==============================================================================
# Ensure HighLine doesn't output deprecation warnings for Ruby 2.7
class HighLine
  def say(statement)
    statement = format_statement(statement)
    return unless statement.length > 0

    out = (indentation+statement).encode(Encoding.default_external, :undef => :replace)

    # Don't add a newline if statement ends with whitespace, OR
    # if statement ends with whitespace before a color escape code.
    if /[ \t](\e\[\d+(;\d+)*m)?\Z/ =~ statement
      @output.print(out)
      @output.flush
    else
      @output.puts(out)
    end
  end
end
