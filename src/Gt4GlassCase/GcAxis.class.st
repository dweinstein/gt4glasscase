"
A named dimension of the hypercube: model_family x revision x precision x backend x probe x variant x seed x decoding_params. Holds its value domain (values) and, for ordinal axes such as precision (bf16 > int8 > int4), an ordering. Invariant I4 -- the hypercube is structural from commit one -- so this class exists before any campaign does.
"
Class {
	#name : 'GcAxis',
	#superclass : 'Object',
	#instVars : [
		'name',
		'values',
		'ordering'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcAxis class >> named: aSymbol values: aCollection [
	^ self new
		name: aSymbol;
		values: aCollection;
		yourself
]

{ #category : 'instance creation' }
GcAxis class >> named: aSymbol values: aCollection ordering: anOrdering [
	| axis |
	axis := self named: aSymbol values: aCollection.
	axis ordering: anOrdering.
	^ axis
]

{ #category : 'views' }
GcAxis >> gtValuesFor: aView [
	"What values can this axis take, and in what order?"
	<gtView>
	^ aView columnedList
		title: 'Values';
		priority: 1;
		items: [ values ifNil: [ #() ] ];
		column: 'Value' text: [ :v | v printString ];
		column: 'Rank' text: [ :v | (self rankOf: v) ifNil: [ '' ] ifNotNil: [ :r | r printString ] ]
]

{ #category : 'testing' }
GcAxis >> isOrdinal [
	^ ordering isNotNil
]

{ #category : 'accessing' }
GcAxis >> name [
	^ name
]

{ #category : 'accessing' }
GcAxis >> name: aSymbol [
	name := aSymbol asSymbol
]

{ #category : 'accessing' }
GcAxis >> ordering [
	^ ordering
]

{ #category : 'accessing' }
GcAxis >> ordering: aCollection [
	ordering := aCollection
]

{ #category : 'printing' }
GcAxis >> printOn: aStream [
	aStream nextPutAll: 'GcAxis('.
	aStream nextPutAll: name asString.
	aStream nextPut: $)
]

{ #category : 'querying' }
GcAxis >> rankOf: aValue [
	"For an ordinal axis (e.g. precision bf16 > int8 > int4), the position of aValue in the ordering, or nil if the axis is not ordinal."
	^ ordering ifNil: [ nil ] ifNotNil: [ :o | o indexOf: aValue ]
]

{ #category : 'accessing' }
GcAxis >> values [
	^ values
]

{ #category : 'accessing' }
GcAxis >> values: aCollection [
	values := aCollection asOrderedCollection
]
