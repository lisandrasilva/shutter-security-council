requires "evm.md"
requires "foundry.md"
// requires "keccak.md"

module KONTROL-LEMMAS
    imports EVM
    imports FOUNDRY
    imports INT-SYMBOLIC
    imports MAP-SYMBOLIC
    imports SET-SYMBOLIC
    // imports KECCAK-LEMMAS

    syntax StepSort ::= Int
                      | Bool
                      | Bytes
                      | Map
                      | Set
 // -------------------------

    syntax KItem ::= runLemma ( StepSort )
                   | doneLemma( StepSort )
 // --------------------------------------
    rule <k> runLemma(T) => doneLemma(T) ... </k>

    rule [keccak-slots-disjoint]:
      keccak ( A ) ==Int keccak ( B ) +Int C => false
      requires notBool 0 ==Int C
      [simplification, concrete(C), comm]

    rule [keccak-slots-disjoint-ml-l]:
      { keccak ( A ) #Equals keccak ( B ) +Int C } => #Bottom
      requires notBool 0 ==Int C
      [simplification, concrete(C)]

    rule [keccak-slots-disjoint-ml-r]:
      { keccak ( B ) +Int C #Equals keccak ( A ) } => #Bottom
      requires notBool 0 ==Int C
      [simplification, concrete(C)]

    rule [lookup-map-update-match]:
      #lookup ( _M:Map [ K1 <- V ] , K2 ) => V
      requires K1 ==Int K2
    [simplification]

    rule [lookup-map-update-nomatch]:
      #lookup ( M:Map [ K1 <- _ ] , K2 ) => #lookup ( M , K2 )
      requires notBool ( K1 ==Int K2 )
    [simplification]

    rule [keccak-injectivity]:
      keccak(A) ==Int keccak(B) => A ==K B
    [simplification]

    rule [lookup-last-byte]:
      A:Bytes ==K #range ( #buf (32 , #lookup ( M:Map [ KEY1:Int <- VALUE:Int ] , KEY0:Int ) ) , maxUInt5 , 1 )
       => (A ==K #range ( #buf (32 , #lookup ( M , KEY0 ) ) , maxUInt5 , 1 ) andBool KEY1 =/=Int KEY0) 
        orBool (A ==K #range ( #buf (32 , VALUE ) , maxUInt5 , 1 ) andBool KEY1 ==Int KEY0)
    [simplification, comm]

    rule K1 in_keys((K2 |-> _ ) M) => K1 ==Int K2 orBool K1 in_keys(M) [simplification]

endmodule