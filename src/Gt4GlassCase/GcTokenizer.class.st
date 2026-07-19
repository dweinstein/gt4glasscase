"
The tokenizer of a revision: vocab size, special tokens, chat template. Deep merge-list / data-mixture inference is Layer F (later, DW-18); this is the light structural handle for now.
"
Class {
	#name : 'GcTokenizer',
	#superclass : 'Object',
	#instVars : [
		'vocabSize',
		'specialTokens',
		'chatTemplate'
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

{ #category : 'initialization' }
GcTokenizer >> initialize [
	super initialize.
	specialTokens := OrderedCollection new
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
GcTokenizer >> vocabSize [
	^ vocabSize
]

{ #category : 'accessing' }
GcTokenizer >> vocabSize: anInteger [
	vocabSize := anInteger
]
