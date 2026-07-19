"
A GcGroup of GcVocabTokens: a tokenizer vocabulary as a first-class, partitionable group, built metadata-only from tokenizer.json (vocab + merges + added tokens). Hosts the anomalous-token lens: which tokens look reserved, unreachable, or byte-weird — the natural trigger candidates.
"
Class {
	#name : 'GcTokenGroup',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTokenGroup class >> fromVocabulary: aVocabDictionary merges: aMergesCollection specialTokens: aSpecialsCollection [
	| specials mergeResults replacement group |
	specials := aSpecialsCollection asSet.
	mergeResults := Set new.
	aMergesCollection do: [ :entry |
		| parts |
		entry isString
			ifTrue: [
				parts := entry substrings: ' '.
				parts size = 2
					ifTrue: [ mergeResults add: parts first , parts last ] ]
			ifFalse: [
				(entry isCollection and: [ entry size = 2 ])
					ifTrue: [ mergeResults add: entry first , entry last ] ] ].
	replacement := Character value: 65533.
	group := self new.
	aVocabDictionary keysAndValuesDo: [ :tokenString :id |
		| token |
		token := GcVocabToken id: id text: tokenString.
		(specials includes: tokenString)
			ifTrue: [ token addFlag: #special ].
		(tokenString size = 6
			and: [ (tokenString beginsWith: '<0x') and: [ tokenString endsWith: '>' ] ])
			ifTrue: [ token addFlag: #byteToken ].
		((tokenString asLowercase includesSubstring: 'reserved')
			or: [ (tokenString asLowercase includesSubstring: 'unused')
				or: [ tokenString beginsWith: '<|extra' ] ])
			ifTrue: [ token addFlag: #reservedPattern ].
		(tokenString anySatisfy: [ :ch | ch asInteger < 32 or: [ ch = replacement ] ])
			ifTrue: [ token addFlag: #weirdBytes ].
		(mergeResults notEmpty
			and: [ tokenString size > 1
				and: [ (token hasFlag: #special) not
					and: [ (token hasFlag: #byteToken) not
						and: [ (mergeResults includes: tokenString) not ] ] ] ])
			ifTrue: [ token addFlag: #unreachable ].
		group addItem: token ].
	^ group
]

{ #category : 'analysis' }
GcTokenGroup >> anomalousTokens [
	^ self items select: [ :t | t isAnomalous ]
]

{ #category : 'analysis' }
GcTokenGroup >> flagCounts [
	| d |
	d := Dictionary new.
	self items do: [ :t |
		t flags do: [ :f |
			d at: f put: (d at: f ifAbsent: [ 0 ]) + 1 ] ].
	^ d
]

{ #category : 'views' }
GcTokenGroup >> gtAnomalousFor: aView [
	<gtView>
	"Which tokens look reserved, unreachable, or byte-weird - the natural trigger candidates?"
	^ aView columnedList
		title: 'Anomalous tokens';
		priority: 1;
		items: [
			(self anomalousTokens asSortedCollection: [ :a :b |
				a flags size > b flags size
					or: [ a flags size = b flags size and: [ a tokenId < b tokenId ] ] ]) asArray ];
		column: 'Id' text: [ :t | t tokenId printString ];
		column: 'Token' text: [ :t | t text printString ];
		column: 'Bytes' text: [ :t | t hexBytes ];
		column: 'Flags' text: [ :t | t flagsString ]
]

{ #category : 'gt actions' }
GcTokenGroup >> gtAnomalousOnlyActionFor: anAction [
	<gtAction>
	^ anAction button
		tooltip: 'Open a derived group of only the anomalous (flagged) tokens';
		priority: 20;
		icon: BrGlamorousVectorIcons search;
		action: [ :aButton |
			aButton phlow spawnObject: (self withItems: self anomalousTokens derivedBy: #anomalous) ]
]

{ #category : 'views' }
GcTokenGroup >> gtFlagSummaryFor: aView [
	<gtView>
	"How many tokens does each anomaly heuristic flag?"
	^ aView columnedList
		title: 'Flags';
		priority: 2;
		items: [ (self flagCounts associations asSortedCollection: [ :a :b | a value > b value ]) asArray ];
		column: 'Flag' text: [ :assoc | assoc key asString ];
		column: 'Count' text: [ :assoc | assoc value printString ];
		send: [ :assoc | self withItems: (self items select: [ :t | t hasFlag: assoc key ]) derivedBy: #flagged ]
]

{ #category : 'gt search' }
GcTokenGroup >> gtSearchAnomalousTokensFor: aSearch [
	<gtSearch>
	^ aSearch list
		title: 'Anomalous tokens';
		priority: 5;
		items: [ self anomalousTokens ];
		itemName: [ :t | t text printString , ' [' , t flagsString , ']' ];
		filterBySubstring
]

{ #category : 'gt search' }
GcTokenGroup >> gtSearchTokensFor: aSearch [
	<gtSearch>
	^ aSearch list
		title: 'Tokens';
		priority: 10;
		items: [ self items ];
		itemName: [ :t | t tokenId printString , ' ' , t text printString ];
		filterBySubstring
]

{ #category : 'printing' }
GcTokenGroup >> printOn: aStream [
	aStream
		nextPutAll: 'vocabulary of ';
		print: self size;
		nextPutAll: ' tokens (';
		print: self anomalousTokens size;
		nextPutAll: ' anomalous)'
]

{ #category : 'analysis' }
GcTokenGroup >> statistics [
	| stats |
	stats := Dictionary new.
	stats at: #count put: self size.
	stats at: #anomalous put: self anomalousTokens size.
	self flagCounts keysAndValuesDo: [ :flag :count | stats at: flag put: count ].
	^ stats
]
