"
The result of one GcConceptProbe: the probed `word`, the `template` used, the ranked top-k predicted next tokens (`entries`, GcLogitLensEntry, most likely first), and the `concepts` (a collection of GcConcept) to match the top prediction against. matchedConcept answers WHICH concept the top prediction's decoded text corresponds to (case-insensitive, whitespace-trimmed match against each concept's name OR its member words) or nil when the model's completion names no known concept -- often the honest Stage-D finding for a 124M model. Views: gtTopFor: (the headline top prediction + matched concept) and gtDetailsFor: (the full top-k table; each row drills into its GcLogitLensEntry).
"
Class {
	#name : 'GcConceptProbeResult',
	#superclass : 'Object',
	#instVars : [
		'word',
		'template',
		'entries',
		'concepts'
	],
	#category : 'Gt4GlassCase-Behavioral',
	#package : 'Gt4GlassCase',
	#tag : 'Behavioral'
}

{ #category : 'instance creation' }
GcConceptProbeResult class >> word: aWord template: aTemplate entries: aCollection [
	^ self new setWord: aWord template: aTemplate entries: aCollection
]

{ #category : 'matching' }
GcConceptProbeResult >> conceptMatching: aText [
	"The (first) concept whose name OR one of whose member words equals aText after whitespace-trim + lowercase, or nil."
	| needle |
	needle := aText trimBoth asLowercase.
	needle isEmpty ifTrue: [ ^ nil ].
	^ self concepts
		detect: [ :c |
			(c name asLowercase = needle)
				or: [ (c words ifNil: [ #() ]) anySatisfy: [ :w | w trimBoth asLowercase = needle ] ] ]
		ifNone: [ nil ]
]

{ #category : 'accessing' }
GcConceptProbeResult >> concepts [
	"The GcConcepts the top prediction is matched against (empty if none supplied)."
	^ concepts ifNil: [ #() ]
]

{ #category : 'accessing' }
GcConceptProbeResult >> concepts: aCollection [
	concepts := aCollection
]

{ #category : 'accessing' }
GcConceptProbeResult >> entries [
	^ entries
]

{ #category : 'accessing' }
GcConceptProbeResult >> entriesOrEmpty [
	^ entries ifNil: [ #() ]
]

{ #category : 'gt - views' }
GcConceptProbeResult >> gtDetailsFor: aView [
	<gtView>
	"The full top-k predicted next tokens; each row drills into its GcLogitLensEntry."
	^ aView columnedList
		title: 'Top-k';
		priority: 10;
		items: [ self entriesOrEmpty ];
		column: 'Rank' text: [ :e | e rank printString ];
		column: 'Token' text: [ :e | e displayToken ];
		column: 'Prob' text: [ :e | e probString ];
		column: 'Logit' text: [ :e | e logitString ];
		send: [ :e | e ]
]

{ #category : 'gt - views' }
GcConceptProbeResult >> gtTopFor: aView [
	<gtView>
	"The headline: the probed word, its prompt, the single top predicted next token, and which concept (if any) it names. Each row drills into a moldable object."
	^ aView columnedList
		title: 'Top prediction';
		priority: 5;
		items: [ self topRows ];
		column: 'Field' text: [ :row | row first ];
		column: 'Value' text: [ :row | row second ];
		send: [ :row | row third ]
]

{ #category : 'matching' }
GcConceptProbeResult >> matchedConcept [
	"WHICH concept the top prediction names (case-insensitive, trimmed), or nil when the completion matches no known concept."
	^ self conceptMatching: self topText
]

{ #category : 'printing' }
GcConceptProbeResult >> printOn: aStream [
	aStream
		nextPutAll: 'probe[';
		nextPutAll: (word ifNil: [ '?' ]);
		nextPutAll: ' -> ';
		nextPutAll: (self topEntry ifNil: [ '?' ] ifNotNil: [ :e | e displayToken ]);
		nextPutAll: ']'
]

{ #category : 'accessing' }
GcConceptProbeResult >> promptText [
	"The filled prompt this result came from."
	^ (template ifNil: [ '' ]) copyReplaceAll: '{word}' with: (word ifNil: [ '' ])
]

{ #category : 'initialization' }
GcConceptProbeResult >> setWord: aWord template: aTemplate entries: aCollection [
	word := aWord.
	template := aTemplate.
	entries := aCollection
]

{ #category : 'accessing' }
GcConceptProbeResult >> template [
	^ template
]

{ #category : 'accessing' }
GcConceptProbeResult >> topEntry [
	"The single most likely predicted next token (a GcLogitLensEntry), or nil."
	^ self entriesOrEmpty isEmpty ifTrue: [ nil ] ifFalse: [ self entriesOrEmpty first ]
]

{ #category : 'accessing' }
GcConceptProbeResult >> topN: n [
	"The first n predicted entries (fewer if there are fewer)."
	^ self entriesOrEmpty first: (n min: self entriesOrEmpty size)
]

{ #category : 'accessing' }
GcConceptProbeResult >> topRows [
	"Headline rows for gtTopFor:, each carrying a moldable drill-in target as its third element."
	| top mc |
	top := self topEntry.
	mc := self matchedConcept.
	^ {
		{ 'Word'. (word ifNil: [ '?' ]). self }.
		{ 'Prompt'. self promptText. self }.
		{ 'Top token'. (top ifNil: [ '-' ] ifNotNil: [ :e | e displayToken ]). (top ifNil: [ self ]) }.
		{ 'Top prob'. (top ifNil: [ '-' ] ifNotNil: [ :e | e probString ]). (top ifNil: [ self ]) }.
		{ 'Matched concept'. (mc ifNil: [ '(none)' ] ifNotNil: [ :c | c name ]). (mc ifNil: [ self ]) } }
]

{ #category : 'accessing' }
GcConceptProbeResult >> topText [
	"The decoded top-prediction text, whitespace-trimmed and lowercased (the key used for concept matching)."
	^ self topEntry
		ifNil: [ '' ]
		ifNotNil: [ :e | (e tokenText ifNil: [ '' ]) trimBoth asLowercase ]
]

{ #category : 'accessing' }
GcConceptProbeResult >> topTokensStringUpTo: n [
	"The first n predicted tokens as a single space-separated display string."
	| parts |
	parts := (self topN: n) collect: [ :e | e displayToken ].
	^ parts isEmpty ifTrue: [ '' ] ifFalse: [ parts fold: [ :a :b | a , ' ' , b ] ]
]

{ #category : 'accessing' }
GcConceptProbeResult >> word [
	^ word
]
