
module Rye; class Box;
  
  
  module Commands
    def wc(*args); command('wc', args); end
    def date(*args); command('date', args); end
    def ls(*args); command('ls', args); end
    def pwd(key=nil); command "pwd"; end
  end

end; end