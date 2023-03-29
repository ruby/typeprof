# update: test0.rb
module M
  class A
  end
end

# update: test1.rb
module M
  class B
    # Defining M::B iterates its const_reads and fires the following
    # BaseConstRead (M) and ScopedConstRead (M::A).
    # The ScopedConstRead attempts to add itself to M's const_reads.
    # This addition is done during the iteration of M's const_reads,
    # so we need to avoid "modification during iteration".
    M::A
  end
end