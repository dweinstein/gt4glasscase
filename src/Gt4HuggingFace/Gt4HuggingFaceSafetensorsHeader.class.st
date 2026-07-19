"
A generic, parsed safetensors header: a plain map of tensorName -> {dtype, shape, data_offsets}, plus __metadata__. No dependency on any domain model -- consumers translate it into their own objects.
"
Class {
	#name : 'Gt4HuggingFaceSafetensorsHeader',
	#superclass : 'Object',
	#instVars : [
		'rawDictionary'
	],
	#category : 'Gt4HuggingFace',
	#package : 'Gt4HuggingFace'
}

{ #category : 'instance creation' }
Gt4HuggingFaceSafetensorsHeader class >> fromDictionary: aDictionary [
	^ self new rawDictionary: aDictionary; yourself
]

{ #category : 'instance creation' }
Gt4HuggingFaceSafetensorsHeader class >> fromString: aJsonString [
	^ self fromDictionary: (STONJSON fromString: aJsonString)
]

{ #category : 'accessing' }
Gt4HuggingFaceSafetensorsHeader >> dtypeFor: aName [
	^ (self infoFor: aName) at: 'dtype'
]

{ #category : 'accessing' }
Gt4HuggingFaceSafetensorsHeader >> infoFor: aName [
	^ rawDictionary at: aName
]

{ #category : 'accessing' }
Gt4HuggingFaceSafetensorsHeader >> metadata [
	^ rawDictionary at: '__metadata__' ifAbsent: [ nil ]
]

{ #category : 'accessing' }
Gt4HuggingFaceSafetensorsHeader >> offsetsFor: aName [
	^ (self infoFor: aName) at: 'data_offsets'
]

{ #category : 'printing' }
Gt4HuggingFaceSafetensorsHeader >> printOn: aStream [
	aStream nextPutAll: 'Gt4HuggingFaceSafetensorsHeader('.
	aStream print: self tensorCount.
	aStream nextPutAll: ' tensors)'
]

{ #category : 'accessing' }
Gt4HuggingFaceSafetensorsHeader >> rawDictionary [
	^ rawDictionary
]

{ #category : 'accessing' }
Gt4HuggingFaceSafetensorsHeader >> rawDictionary: aDictionary [
	rawDictionary := aDictionary
]

{ #category : 'accessing' }
Gt4HuggingFaceSafetensorsHeader >> shapeFor: aName [
	^ (self infoFor: aName) at: 'shape'
]

{ #category : 'accessing' }
Gt4HuggingFaceSafetensorsHeader >> tensorCount [
	^ self tensorNames size
]

{ #category : 'accessing' }
Gt4HuggingFaceSafetensorsHeader >> tensorNames [
	^ (rawDictionary keys reject: [ :k | k = '__metadata__' ]) asSortedCollection asArray
]
