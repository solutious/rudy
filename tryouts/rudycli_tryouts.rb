
class RudyCLI < Tryouts
  command :rudy

  tryout "rudy machines" do
    drill "no machines, no args", :machines
  end


  tryout "rudy myaddress" do
    drill       'no args',     :myaddress
    drill 'internal only',     :myaddress, :i
    drill 'external only',     :myaddress, :e
    drill         'quiet', :q, :myaddress
  end
  
   
end
  
  