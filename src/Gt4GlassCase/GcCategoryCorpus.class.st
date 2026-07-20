"
SCAFFOLD (DW-18, Tier-2 boundary object): a named category corpus -- a handle onto sample text representative of one data category (e.g. 'code', 'cjk', 'english-prose'). Holds only a name and a sample-text String; it carries NO tokenization and NO frequency model. It is an INPUT to the data-mixture inference whose heavy numerical solve (given category corpora, recover per-category training proportions from a tokenizer's merge list) is a Python/Tier-2 job in gc-harness -- see GcMixtureInference. This Smalltalk object exists so the boundary is explorable in-image; it deliberately does not implement the linear program (invariant I10).
"
Class {
	#name : 'GcCategoryCorpus',
	#superclass : 'Object',
	#instVars : [
		'name',
		'sampleText'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcCategoryCorpus class >> name: aString sampleText: aText [
	^ self new setName: aString sampleText: aText
]

{ #category : 'gt views' }
GcCategoryCorpus >> gtSampleTextFor: aView [
	<gtView>
	"The sample text representative of this category."
	sampleText ifNil: [ ^ aView empty ].
	^ aView textEditor
		title: 'Sample text';
		priority: 1;
		text: [ sampleText ]
]

{ #category : 'accessing' }
GcCategoryCorpus >> name [
	^ name
]

{ #category : 'accessing' }
GcCategoryCorpus >> name: aString [
	name := aString
]

{ #category : 'printing' }
GcCategoryCorpus >> printOn: aStream [
	aStream nextPutAll: 'corpus '; nextPutAll: (name ifNil: [ '?' ]); nextPutAll: ' ('; print: self size; nextPutAll: ' chars)'
]

{ #category : 'accessing' }
GcCategoryCorpus >> sampleText [
	^ sampleText
]

{ #category : 'accessing' }
GcCategoryCorpus >> sampleText: aText [
	sampleText := aText
]

{ #category : 'initialization' }
GcCategoryCorpus >> setName: aString sampleText: aText [
	name := aString.
	sampleText := aText
]

{ #category : 'accessing' }
GcCategoryCorpus >> size [
	"Number of characters in the sample text."
	^ sampleText ifNil: [ 0 ] ifNotNil: [ :t | t size ]
]
