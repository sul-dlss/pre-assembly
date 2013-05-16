module PreAssembly

  module Project

    module Revs
            
      # a hash of LC Subject Heading terms and their IDs for linking for "Automobiles" http://id.loc.gov/authorities/subjects/sh85010201.html
      # this is cached and loaded from disk and deserialized back into a hash for performance reasons, then stored as a module
      # level constant so it can be reused throughout the pre-assembly run as a constant
      #  This cached set of terms can be re-generated with "ruby devel/revs_lc_automobile_terms.rb"
      AUTOMOBILE_LC_TERMS= File.open(REVS_LC_TERMS_FILENAME,'rb'){|io| Marshal.load(io)}
      
      # lookup the marque sent to see if it matches any known LC terms, trying a few varieties; returns a hash of the term and its ID if match is found, else returns false
      def revs_lookup_marque(marque)
        result=false
        variants1=[marque,marque.capitalize,marque.singularize,marque.pluralize,marque.capitalize.singularize,marque.capitalize.pluralize]
        variants2=[]
        variants1.each do |name| 
          variants2 << "#{name} automobile" 
          variants2 << "#{name} automobiles"
        end
        (variants1+variants2).each do |variant|
          lookup_term=AUTOMOBILE_LC_TERMS[variant]
          if lookup_term
            result={'url'=>lookup_term,'value'=>variant}
            break
          end
        end
        return result
      end
      
    end
    
  end
  
end