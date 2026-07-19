"
A parsed structural tensor path, e.g. model.layers.31.self_attn.q_proj.weight. The highest-leverage parse in the project: every accessor becomes a grouping key, every grouping key a view.
"
Class {
	#name : 'GcTensorName',
	#superclass : 'Object',
	#instVars : [
		'raw',
		'layerIndex',
		'role',
		'module',
		'block',
		'expertIndex'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTensorName class >> from: aString [
	^ self new
		raw: aString;
		parse;
		yourself
]

{ #category : 'accessing' }
GcTensorName >> block [
	^ block
]

{ #category : 'private' }
GcTensorName >> blockFor: parts [
	(parts includes: 'self_attn') ifTrue: [ ^ #attention ].
	(parts includes: 'mlp') ifTrue: [ ^ #mlp ].
	(parts anySatisfy: [ :p | p includesSubstring: 'embed' ]) ifTrue: [ ^ #embedding ].
	(parts anySatisfy: [ :p | p includesSubstring: 'norm' ]) ifTrue: [ ^ #norm ].
	^ #other
]

{ #category : 'accessing' }
GcTensorName >> expertIndex [
	^ expertIndex
]

{ #category : 'private' }
GcTensorName >> expertIndexFrom: parts [
	| idx |
	idx := parts indexOf: 'experts'.
	idx = 0 ifTrue: [ ^ nil ].
	^ (idx < parts size and: [ self isNumeric: (parts at: idx + 1) ])
		ifTrue: [ (parts at: idx + 1) asInteger ]
		ifFalse: [ nil ]
]

{ #category : 'testing' }
GcTensorName >> isExpert [
	^ expertIndex notNil
]

{ #category : 'private' }
GcTensorName >> isNumeric: aString [
	^ aString notEmpty and: [ aString allSatisfy: [ :c | c isDigit ] ]
]

{ #category : 'accessing' }
GcTensorName >> layerIndex [
	^ layerIndex
]

{ #category : 'accessing' }
GcTensorName >> module [
	^ module
]

{ #category : 'parsing' }
GcTensorName >> parse [
	"Parse a structured tensor path into layerIndex, role, module, block and expertIndex."
	| parts |
	parts := raw substrings: '.'.
	layerIndex := (parts detect: [ :p | self isNumeric: p ] ifNone: [ nil ])
		ifNotNil: [ :s | s asInteger ].
	role := parts isEmpty ifTrue: [ nil ] ifFalse: [ parts last ].
	module := parts size >= 2 ifTrue: [ parts at: parts size - 1 ] ifFalse: [ nil ].
	block := self blockFor: parts.
	expertIndex := self expertIndexFrom: parts.
	^ self
]

{ #category : 'printing' }
GcTensorName >> printOn: aStream [
	aStream nextPutAll: 'GcTensorName('.
	aStream nextPutAll: (raw ifNil: [ '?' ]).
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcTensorName >> raw [
	^ raw
]

{ #category : 'accessing' }
GcTensorName >> raw: aString [
	raw := aString
]

{ #category : 'accessing' }
GcTensorName >> role [
	^ role
]
