"
A specific published revision, identified as repositoryId @ commitSha (e.g. 'Qwen/Qwen3-32B' @ 'a1b2c3d'). THE unit of scientific identity: friendly names hide silent re-uploads, so every observation is anchored to a commit SHA.
"
Class {
	#name : 'GcModelRevision',
	#superclass : 'Object',
	#instVars : [
		'family',
		'repositoryId',
		'commitSha',
		'provenance'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcModelRevision class >> repository: aRepositoryId commit: aSha [
	^ self repository: aRepositoryId commit: aSha family: nil
]

{ #category : 'instance creation' }
GcModelRevision class >> repository: aRepositoryId commit: aSha family: aFamily [
	^ self new
		repositoryId: aRepositoryId;
		commitSha: aSha;
		family: aFamily;
		yourself
]

{ #category : 'accessing' }
GcModelRevision >> commitSha [
	^ commitSha
]

{ #category : 'accessing' }
GcModelRevision >> commitSha: aString [
	commitSha := aString
]

{ #category : 'accessing' }
GcModelRevision >> family [
	^ family
]

{ #category : 'accessing' }
GcModelRevision >> family: aFamily [
	family := aFamily
]

{ #category : 'accessing' }
GcModelRevision >> id [
	"The unit of scientific identity: repositoryId @ commitSha."
	^ String streamContents: [ :s |
		s nextPutAll: (repositoryId ifNil: [ '?' ]).
		s nextPut: $@.
		s nextPutAll: (commitSha ifNil: [ '?' ]) ]
]

{ #category : 'printing' }
GcModelRevision >> printOn: aStream [
	aStream nextPutAll: 'GcModelRevision('.
	aStream nextPutAll: self id.
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcModelRevision >> provenance [
	^ provenance
]

{ #category : 'accessing' }
GcModelRevision >> provenance: aProvenance [
	provenance := aProvenance
]

{ #category : 'accessing' }
GcModelRevision >> repositoryId [
	^ repositoryId
]

{ #category : 'accessing' }
GcModelRevision >> repositoryId: aString [
	repositoryId := aString
]
