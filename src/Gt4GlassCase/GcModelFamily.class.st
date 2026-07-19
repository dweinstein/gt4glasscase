"
A logical model across all its revisions and precisions, e.g. 'Qwen3-32B'. A family name is convenient but is NOT a scientific object on its own -- scientific identity lives on GcModelRevision (I1).
"
Class {
	#name : 'GcModelFamily',
	#superclass : 'Object',
	#instVars : [
		'name',
		'publisher'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcModelFamily class >> name: aString publisher: anotherString [
	^ self new
		name: aString;
		publisher: anotherString;
		yourself
]

{ #category : 'views' }
GcModelFamily >> gtDetailsFor: aView [
	"Which logical model is this?"
	<gtView>
	^ aView columnedList
		title: 'Family';
		priority: 1;
		items: [ { 'Name' -> (name ifNil: [ '-' ]). 'Publisher' -> (publisher ifNil: [ '-' ]) } ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ]
]

{ #category : 'accessing' }
GcModelFamily >> name [
	^ name
]

{ #category : 'accessing' }
GcModelFamily >> name: aString [
	name := aString
]

{ #category : 'printing' }
GcModelFamily >> printOn: aStream [
	aStream nextPutAll: 'GcModelFamily('.
	aStream nextPutAll: (name ifNil: [ '?' ]).
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcModelFamily >> publisher [
	^ publisher
]

{ #category : 'accessing' }
GcModelFamily >> publisher: aString [
	publisher := aString
]
