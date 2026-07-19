"
Where an artifact came from: publisher, license, release date, announcement URL, and the mirror/derivation chain from the original publisher to the file on disk.
"
Class {
	#name : 'GcProvenance',
	#superclass : 'Object',
	#instVars : [
		'publisher',
		'license',
		'releaseDate',
		'announcementUrl',
		'mirrorChain'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcProvenance class >> publisher: aPublisher license: aLicense [
	^ self new
		publisher: aPublisher;
		license: aLicense;
		yourself
]

{ #category : 'building' }
GcProvenance >> addMirror: aString [
	mirrorChain add: aString.
	^ aString
]

{ #category : 'accessing' }
GcProvenance >> announcementUrl [
	^ announcementUrl
]

{ #category : 'accessing' }
GcProvenance >> announcementUrl: aString [
	announcementUrl := aString
]

{ #category : 'views' }
GcProvenance >> detailFacets [
	^ {
		'Publisher' -> publisher.
		'License' -> license.
		'Release date' -> releaseDate.
		'Announcement' -> announcementUrl.
		'Mirror chain' -> mirrorChain }
]

{ #category : 'views' }
GcProvenance >> gtDetailsFor: aView [
	"Where did this artifact come from?"
	<gtView>
	^ aView columnedList
		title: 'Provenance';
		priority: 1;
		items: [ self detailFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | (v isCollection and: [ v isString not ]) ifTrue: [ v printString ] ifFalse: [ v displayString ] ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'initialization' }
GcProvenance >> initialize [
	super initialize.
	mirrorChain := OrderedCollection new
]

{ #category : 'accessing' }
GcProvenance >> license [
	^ license
]

{ #category : 'accessing' }
GcProvenance >> license: aString [
	license := aString
]

{ #category : 'accessing' }
GcProvenance >> mirrorChain [
	^ mirrorChain
]

{ #category : 'accessing' }
GcProvenance >> mirrorChain: aCollection [
	mirrorChain := aCollection asOrderedCollection
]

{ #category : 'printing' }
GcProvenance >> printOn: aStream [
	aStream nextPutAll: 'GcProvenance('.
	aStream nextPutAll: (publisher ifNil: [ '?' ]).
	aStream nextPutAll: ', '.
	aStream nextPutAll: (license ifNil: [ '?' ]).
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcProvenance >> publisher [
	^ publisher
]

{ #category : 'accessing' }
GcProvenance >> publisher: aString [
	publisher := aString
]

{ #category : 'accessing' }
GcProvenance >> releaseDate [
	^ releaseDate
]

{ #category : 'accessing' }
GcProvenance >> releaseDate: aDate [
	releaseDate := aDate
]
