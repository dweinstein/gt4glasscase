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
		'tokenGroup'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTokenizer class >> vocabSize: anInteger [
	^ self new vocabSize: anInteger; yourself
]

{ #category : 'accessing' }
GcTokenizer >> chatTemplate [
	^ chatTemplate
]

{ #category : 'accessing' }
GcTokenizer >> chatTemplate: aString [
	chatTemplate := aString
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

{ #category : 'initialization' }
GcTokenizer >> initialize [
	super initialize.
	specialTokens := OrderedCollection new
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

{ #category : 'printing' }
GcTokenizer >> printOn: aStream [
	aStream nextPutAll: 'GcTokenizer(vocab: '.
	aStream print: (vocabSize ifNil: [ 0 ]).
	aStream nextPut: $)
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
GcTokenizer >> vocabSize [
	^ vocabSize
]

{ #category : 'accessing' }
GcTokenizer >> vocabSize: anInteger [
	vocabSize := anInteger
]
