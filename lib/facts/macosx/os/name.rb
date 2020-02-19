# frozen_string_literal: true

module Facter
  module Macosx
    class OsName
      FACT_NAME = 'os.name'
      ALIASES = 'operatingsystem'

      def call_the_resolver
        fact_value = Resolvers::Uname.resolve(:kernelname)

        [ResolvedFact.new(FACT_NAME, fact_value), ResolvedFact.new(ALIASES, fact_value, :legacy)]
      end
    end
  end
end