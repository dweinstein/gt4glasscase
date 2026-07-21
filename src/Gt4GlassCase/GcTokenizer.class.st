"
The tokenizer of a revision: vocab size, special tokens, chat template. Deep merge-list / data-mixture inference is Layer F (later, DW-18); this is the light structural handle for now.
"
Class {
	#name : 'GcTokenizer',
	#superclass : 'Object',
	#instVars : [
		'vocabSize',
		'specialTokens',
		'chatTemplate',
		'mergeList',
		'tokenGroup',
		'vocab',
		'byteEncoder'
	],
	#classVars : [
		'DefaultGpt2'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation - gpt2' }
GcTokenizer class >> cachePath [
	"Local glassbox cache holding the GPT-2 vocab/merges (shared with GcGpt2Decoder)."
	^ GcGpt2Decoder cachePath
]

{ #category : 'instance creation - gpt2' }
GcTokenizer class >> gpt2 [
	"The memoized shared GPT-2 byte-level BPE tokenizer: vocab + merges are parsed at most once per image."
	^ DefaultGpt2 ifNil: [ DefaultGpt2 := self openGpt2 ]
]

{ #category : 'instance creation - gpt2' }
GcTokenizer class >> openGpt2 [
	"Load vocab.json (piece -> id) and merges.txt (ranked BPE merges) from the local glassbox cache and build a fully-configured GPT-2 byte-level BPE tokenizer."
	| dir vocabDict tok |
	dir := self cachePath.
	vocabDict := STONJSON fromString: (dir / 'vocab.json') contents.
	tok := self new.
	tok
		vocab: vocabDict;
		vocabSize: vocabDict size;
		mergeList: (GcMergeList fromMergesText: (dir / 'merges.txt') contents);
		specialTokens: (OrderedCollection with: '<|endoftext|>').
	^ tok
]

{ #category : 'instance creation - gpt2' }
GcTokenizer class >> reset [
	"Drop the memoized GPT-2 tokenizer so the next #gpt2 reloads from the cache."
	DefaultGpt2 := nil
]

{ #category : 'instance creation' }
GcTokenizer class >> vocabSize: anInteger [
	^ self new vocabSize: anInteger; yourself
]

{ #category : 'encoding - bpe' }
GcTokenizer >> bpeMergePieces: aWord [
	"Run GPT-2 BPE over aWord (an OrderedCollection of byte-level piece strings): repeatedly fuse the adjacent pair with the lowest merge rank (from the merge list) until no mergeable pair remains."
	| word continue |
	word := aWord.
	continue := true.
	[ continue and: [ word size > 1 ] ] whileTrue: [
		| bestPair bestRank |
		bestPair := nil.
		bestRank := nil.
		1 to: word size - 1 do: [ :idx |
			| pair rank |
			pair := { word at: idx. word at: idx + 1 }.
			rank := self mergeList rankOfPair: pair.
			(rank notNil and: [ bestRank isNil or: [ rank < bestRank ] ])
				ifTrue: [ bestRank := rank. bestPair := pair ] ].
		bestPair isNil
			ifTrue: [ continue := false ]
			ifFalse: [ word := self mergeAllOccurrencesOf: bestPair in: word ] ].
	^ word
]

{ #category : 'encoding - bytes' }
GcTokenizer >> buildByteEncoder [
	"Build GPT-2's bytes_to_unicode map forward: byte (0..255) -> Character. Same table the decoder inverts. The codepoint list is copied with OrderedCollection withAll: (NOT asOrderedCollection, which would alias bs and corrupt the map as bs grows)."
	| bs cs n enc |
	bs := OrderedCollection new.
	33 to: 126 do: [ :b | bs add: b ].
	161 to: 172 do: [ :b | bs add: b ].
	174 to: 255 do: [ :b | bs add: b ].
	cs := OrderedCollection withAll: bs.
	n := 0.
	0 to: 255 do: [ :b |
		(bs includes: b) ifFalse: [
			bs add: b.
			cs add: 256 + n.
			n := n + 1 ] ].
	enc := Dictionary new.
	1 to: bs size do: [ :i | enc at: (bs at: i) put: (Character value: (cs at: i)) ].
	^ enc
]

{ #category : 'encoding - bytes' }
GcTokenizer >> byteEncoder [
	"GPT-2's bytes_to_unicode map (byte 0..255 -> Character), built lazily and cached."
	^ byteEncoder ifNil: [ byteEncoder := self buildByteEncoder ]
]

{ #category : 'encoding - pretokenizer' }
GcTokenizer >> categoryOfChar: aCharacter [
	"Coarse pre-tokenizer character class: #ws #letter #digit #other. Byte-level BPE never sees whitespace inside a piece."
	(self isWhitespaceChar: aCharacter) ifTrue: [ ^ #ws ].
	aCharacter isLetter ifTrue: [ ^ #letter ].
	aCharacter isDigit ifTrue: [ ^ #digit ].
	^ #other
]

{ #category : 'accessing' }
GcTokenizer >> chatTemplate [
	^ chatTemplate
]

{ #category : 'accessing' }
GcTokenizer >> chatTemplate: aString [
	chatTemplate := aString
]

{ #category : 'encoding' }
GcTokenizer >> decode: aCollectionOfIds [
	"Decode token ids back to a String via the shared GPT-2 decoder (id -> piece -> bytes -> UTF-8)."
	^ GcGpt2Decoder default decodeIds: aCollectionOfIds
]

{ #category : 'encoding' }
GcTokenizer >> encode: aString [
	"Encode a String to an Array of GPT-2 byte-level BPE token ids. Registered special tokens (e.g. <|endoftext|>) are recognised as atomic."
	^ ((self encodeToTuples: aString) collect: [ :tuple | tuple second ]) asArray
]

{ #category : 'encoding' }
GcTokenizer >> encodeToTuples: aString [
	"Ordered { piece. id. isSpecial } tuples for aString: split on registered special tokens, byte-level-BPE the text segments."
	| tuples |
	tuples := OrderedCollection new.
	(self segmentsFor: aString) do: [ :seg |
		seg key == #special
			ifTrue: [ tuples add: { seg value. (self idForPiece: seg value). true } ]
			ifFalse: [
				(self preTokenize: seg value) do: [ :pt |
					| chars pieces |
					chars := OrderedCollection new.
					pt asUTF8Bytes do: [ :b | chars add: (self byteEncoder at: b) asString ].
					pieces := self bpeMergePieces: chars.
					pieces do: [ :pc | tuples add: { pc. (self idForPiece: pc). false } ] ] ] ].
	^ tuples
]

{ #category : 'encoding' }
GcTokenizer >> encodingFor: aString [
	"Encode aString into a moldable GcEncoding: ordered GcEncodedTokens with id, byte-level piece, source byte span (each byte-level char = one source byte) and special flag."
	| tuples tokens offset enc |
	tuples := self encodeToTuples: aString.
	tokens := OrderedCollection new.
	offset := 0.
	tuples doWithIndex: [ :t :i |
		| piece len tok |
		piece := t first.
		len := piece size.
		tok := GcEncodedToken new
			index: i;
			tokenId: t second;
			piece: piece;
			special: t third;
			byteStart: offset;
			byteStop: offset + len - 1;
			yourself.
		offset := offset + len.
		tokens add: tok ].
	enc := GcEncoding new
		sourceString: aString;
		tokens: tokens;
		tokenizer: self;
		yourself.
	tokens do: [ :tk | tk encoding: enc ].
	^ enc
]

{ #category : 'gt views' }
GcTokenizer >> gtCorpusFingerprintFor: aView [
	<gtView>
	"Forwarded corpus-fingerprint of the attached merge list. Empty until a merge list is attached."
	mergeList ifNil: [ ^ aView empty ].
	^ aView forward
		title: 'Corpus fingerprint';
		priority: 4;
		object: [ mergeList ];
		view: #gtCorpusFingerprintFor:
]

{ #category : 'gt views' }
GcTokenizer >> gtMergesFor: aView [
	<gtView>
	"Forwarded merge list. Empty until a merge list is attached."
	mergeList ifNil: [ ^ aView empty ].
	^ aView forward
		title: 'Merges';
		priority: 6;
		object: [ mergeList ];
		view: #gtMergesFor:
]

{ #category : 'gt views' }
GcTokenizer >> gtSuspectedManualMergesFor: aView [
	<gtView>
	"Forwarded suspected-manual-merges heuristic. Empty until a merge list is attached."
	mergeList ifNil: [ ^ aView empty ].
	^ aView forward
		title: 'Suspected manual merges';
		priority: 7;
		object: [ mergeList ];
		view: #gtSuspectedManualMergesFor:
]

{ #category : 'gt views' }
GcTokenizer >> gtVocabFor: aView [
	<gtView>
	"The full vocabulary as a list (forwarded from the token group). Empty until a token group is attached."
	tokenGroup ifNil: [ ^ aView empty ].
	^ aView forward
		title: 'Vocabulary';
		priority: 5;
		object: [ tokenGroup ];
		view: #gtItemsFor:
]

{ #category : 'encoding - vocab' }
GcTokenizer >> idForPiece: aPieceString [
	"The token id of a byte-level piece string (raises if absent)."
	^ self vocab at: aPieceString
]

{ #category : 'initialization' }
GcTokenizer >> initialize [
	super initialize.
	specialTokens := OrderedCollection new
]

{ #category : 'encoding - pretokenizer' }
GcTokenizer >> isWhitespaceChar: aCharacter [
	"GPT-2's \s: ASCII tab, LF, VT, FF, CR and space."
	^ #(9 10 11 12 13 32) includes: aCharacter asInteger
]

{ #category : 'encoding - bpe' }
GcTokenizer >> mergeAllOccurrencesOf: aPair in: aWord [
	"Return aWord with every adjacent occurrence of aPair {left. right} fused into the single piece left , right."
	| left right result i |
	left := aPair first.
	right := aPair second.
	result := OrderedCollection new.
	i := 1.
	[ i <= aWord size ] whileTrue: [
		((aWord at: i) = left and: [ i < aWord size and: [ (aWord at: i + 1) = right ] ])
			ifTrue: [ result add: left , right. i := i + 2 ]
			ifFalse: [ result add: (aWord at: i). i := i + 1 ] ].
	^ result
]

{ #category : 'accessing' }
GcTokenizer >> mergeList [
	"The BPE merge list (DW-18, Layer F), or nil if not attached."
	^ mergeList
]

{ #category : 'accessing' }
GcTokenizer >> mergeList: aMergeList [
	mergeList := aMergeList.
	aMergeList ifNotNil: [ aMergeList tokenizer: self ]
]

{ #category : 'merge ranks' }
GcTokenizer >> mergeRankForToken: aTokenString [
	"The merge rank at which the given piece string was first formed, or nil (base byte / no merge list)."
	^ mergeList ifNil: [ nil ] ifNotNil: [ :ml | ml rankForToken: aTokenString ]
]

{ #category : 'merge ranks' }
GcTokenizer >> mergeRankForTokenId: anId [
	"The merge rank of the vocab token with this id (resolved via the token group), or nil. NOT for render blocks: a linear scan over the vocabulary."
	| tok |
	tokenGroup ifNil: [ ^ nil ].
	tok := tokenGroup items detect: [ :t | t tokenId = anId ] ifNone: [ nil ].
	tok ifNil: [ ^ nil ].
	^ self mergeRankForToken: tok text
]

{ #category : 'encoding - pretokenizer' }
GcTokenizer >> preTokenize: aString [
	"GPT-2's regex pre-tokenizer as an explicit character-class scanner: the 's|'t|'re|'ve|'m|'ll|'d contractions, then a single optional leading SPACE (0x20) before a run of letters / digits / other, then whitespace runs (leaving a trailing single space to attach to the next token). Returns the ordered pre-token substrings."
	| out i n |
	out := OrderedCollection new.
	i := 1.
	n := aString size.
	[ i <= n ] whileTrue: [
		| c done |
		c := aString at: i.
		done := false.
		c = $' ifTrue: [
			| two |
			two := (i + 2 <= n) ifTrue: [ aString copyFrom: i + 1 to: i + 2 ] ifFalse: [ '' ].
			(#('re' 've' 'll') includes: two)
				ifTrue: [ out add: (aString copyFrom: i to: i + 2). i := i + 3. done := true ]
				ifFalse: [
					(i + 1 <= n and: [ #($s $t $m $d) includes: (aString at: i + 1) ])
						ifTrue: [ out add: (aString copyFrom: i to: i + 1). i := i + 2. done := true ] ] ].
		done ifFalse: [
			(c asInteger = 32 and: [ i < n and: [ (self isWhitespaceChar: (aString at: i + 1)) not ] ])
				ifTrue: [
					| cat j |
					cat := self categoryOfChar: (aString at: i + 1).
					j := i + 1.
					[ j <= n and: [ (self isWhitespaceChar: (aString at: j)) not and: [ (self categoryOfChar: (aString at: j)) = cat ] ] ]
						whileTrue: [ j := j + 1 ].
					out add: (aString copyFrom: i to: j - 1).
					i := j ]
				ifFalse: [
					(self isWhitespaceChar: c)
						ifTrue: [
							| k lastWs |
							k := i.
							[ k <= n and: [ self isWhitespaceChar: (aString at: k) ] ] whileTrue: [ k := k + 1 ].
							lastWs := k - 1.
							(k <= n and: [ (aString at: lastWs) asInteger = 32 ])
								ifTrue: [
									(lastWs - 1 >= i) ifTrue: [ out add: (aString copyFrom: i to: lastWs - 1) ].
									i := lastWs ]
								ifFalse: [ out add: (aString copyFrom: i to: lastWs). i := lastWs + 1 ] ]
						ifFalse: [
							| cat j |
							cat := self categoryOfChar: c.
							j := i.
							[ j <= n and: [ (self isWhitespaceChar: (aString at: j)) not and: [ (self categoryOfChar: (aString at: j)) = cat ] ] ]
								whileTrue: [ j := j + 1 ].
							out add: (aString copyFrom: i to: j - 1).
							i := j ] ] ] ].
	^ out
]

{ #category : 'printing' }
GcTokenizer >> printOn: aStream [
	aStream nextPutAll: 'GcTokenizer(vocab: '.
	aStream print: (vocabSize ifNil: [ 0 ]).
	aStream nextPut: $)
]

{ #category : 'encoding - specials' }
GcTokenizer >> segmentsFor: aString [
	"Split aString around any registered special-token literal into ordered associations (#text -> plain text, #special -> special-token string). With no specials configured or present, a single #text segment."
	| segments rest specials |
	specials := self specialTokens ifNil: [ #() ].
	segments := OrderedCollection new.
	rest := aString.
	[ rest isEmpty ] whileFalse: [
		| bestIndex bestSpecial |
		bestIndex := nil.
		bestSpecial := nil.
		specials do: [ :sp |
			sp isEmpty ifFalse: [
				| idx |
				idx := rest indexOfSubCollection: sp.
				(idx > 0 and: [ bestIndex isNil or: [ idx < bestIndex ] ])
					ifTrue: [ bestIndex := idx. bestSpecial := sp ] ] ].
		bestIndex isNil
			ifTrue: [ segments add: (#text -> rest). rest := '' ]
			ifFalse: [
				bestIndex > 1 ifTrue: [ segments add: (#text -> (rest copyFrom: 1 to: bestIndex - 1)) ].
				segments add: (#special -> bestSpecial).
				rest := rest copyFrom: bestIndex + bestSpecial size to: rest size ] ].
	^ segments
]

{ #category : 'accessing' }
GcTokenizer >> specialTokens [
	^ specialTokens
]

{ #category : 'accessing' }
GcTokenizer >> specialTokens: aCollection [
	specialTokens := aCollection asOrderedCollection
]

{ #category : 'accessing' }
GcTokenizer >> tokenGroup [
	"The vocabulary lens (GcTokenGroup), or nil if not attached."
	^ tokenGroup
]

{ #category : 'accessing' }
GcTokenizer >> tokenGroup: aTokenGroup [
	tokenGroup := aTokenGroup
]

{ #category : 'accessing' }
GcTokenizer >> vocab [
	"The piece -> id vocabulary Dictionary, or nil if not attached."
	^ vocab
]

{ #category : 'accessing' }
GcTokenizer >> vocab: aDictionary [
	vocab := aDictionary
]

{ #category : 'accessing' }
GcTokenizer >> vocabSize [
	^ vocabSize
]

{ #category : 'accessing' }
GcTokenizer >> vocabSize: anInteger [
	vocabSize := anInteger
]
