"
A reference to one tensor: name, dtype, shape, byte offsets, owning file. NEVER holds bytes (I5) -- browsing a 671B model must work on a laptop.
"
Class {
	#name : 'GcTensorRef',
	#superclass : 'Object',
	#instVars : [
		'name',
		'dtype',
		'shape',
		'beginOffset',
		'endOffset',
		'file'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTensorRef class >> name: aName dtype: aDtype shape: aShape [
	^ self new
		name: aName;
		dtype: aDtype;
		shape: aShape;
		yourself
]

{ #category : 'accessing' }
GcTensorRef >> beginOffset [
	^ beginOffset
]

{ #category : 'accessing' }
GcTensorRef >> beginOffset: anInteger [
	beginOffset := anInteger
]

{ #category : 'querying' }
GcTensorRef >> byteSize [
	^ (beginOffset notNil and: [ endOffset notNil ])
		ifTrue: [ endOffset - beginOffset ]
		ifFalse: [ 0 ]
]

{ #category : 'views' }
GcTensorRef >> detailFacets [
	| pn |
	pn := self parsedName.
	^ {
		'Name' -> name.
		'Dtype' -> dtype.
		'Shape' -> shape.
		'Params' -> self paramCount.
		'Bytes' -> self byteSize.
		'Byte range' -> (beginOffset ifNil: [ nil ] ifNotNil: [ :b | b printString, ' .. ', endOffset printString ]).
		'Layer' -> pn layerIndex.
		'Block' -> pn block.
		'Module' -> pn module.
		'Role' -> pn role.
		'Expert' -> pn expertIndex.
		'Parsed name' -> pn }
]

{ #category : 'accessing' }
GcTensorRef >> dtype [
	^ dtype
]

{ #category : 'accessing' }
GcTensorRef >> dtype: aSymbol [
	dtype := aSymbol
]

{ #category : 'numerics' }
GcTensorRef >> dtypeByteWidth [
	"Bytes per element for the tensor's dtype (safetensors names, lowercased)."
	^ (Dictionary new)
		at: #f64 put: 8; at: #i64 put: 8; at: #u64 put: 8;
		at: #f32 put: 4; at: #i32 put: 4; at: #u32 put: 4;
		at: #f16 put: 2; at: #bf16 put: 2; at: #i16 put: 2; at: #u16 put: 2;
		at: #f8_e4m3 put: 1; at: #f8_e5m2 put: 1; at: #i8 put: 1; at: #u8 put: 1; at: #bool put: 1;
		at: dtype ifAbsent: [ nil ]
]

{ #category : 'numerics' }
GcTensorRef >> elementCount [
	"Number of elements = product of the shape dimensions (1 for a scalar)."
	^ (shape isNil or: [ shape isEmpty ])
		ifTrue: [ 1 ]
		ifFalse: [ shape inject: 1 into: [ :product :dim | product * dim ] ]
]

{ #category : 'accessing' }
GcTensorRef >> endOffset [
	^ endOffset
]

{ #category : 'accessing' }
GcTensorRef >> endOffset: anInteger [
	endOffset := anInteger
]

{ #category : 'accessing' }
GcTensorRef >> file [
	^ file
]

{ #category : 'accessing' }
GcTensorRef >> file: aFile [
	file := aFile
]

{ #category : 'views' }
GcTensorRef >> gtDetailsFor: aView [
	"What is this tensor and where does it live in the model?"
	<gtView>
	^ aView columnedList
		title: 'Tensor';
		priority: 1;
		items: [ self detailFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | (v isCollection and: [ v isString not ]) ifTrue: [ v printString ] ifFalse: [ v displayString ] ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'querying' }
GcTensorRef >> layerIndex [
	^ self parsedName layerIndex
]

{ #category : 'querying' }
GcTensorRef >> module [
	^ self parsedName module
]

{ #category : 'accessing' }
GcTensorRef >> name [
	^ name
]

{ #category : 'accessing' }
GcTensorRef >> name: aString [
	name := aString
]

{ #category : 'numerics' }
GcTensorRef >> paramCount [
	^ self elementCount
]

{ #category : 'querying' }
GcTensorRef >> parsedName [
	^ GcTensorName from: name
]

{ #category : 'printing' }
GcTensorRef >> printOn: aStream [
	aStream nextPutAll: 'GcTensorRef('.
	aStream nextPutAll: (name ifNil: [ '?' ]).
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcTensorRef >> shape [
	^ shape
]

{ #category : 'accessing' }
GcTensorRef >> shape: aCollection [
	shape := aCollection
]
