"
ADAPTER-side bytes port: given absolute byte offsets into a HuggingFace-hosted safetensors file, returns exactly those bytes via an HTTP Range request (Gt4HuggingFaceClient>>rangeBytesFrom:start:end:). Wired onto a core GcSafetensorsFile by the GcHuggingFaceModelSource adapter so the core stays transport-free (hexagonal). Also answers provideByteDataOffset (8 + safetensors header length) by reading the leading 8 bytes once. Never downloads weights wholesale (I5) -- callers request small sampled spans only.
"
Class {
	#name : 'GcHuggingFaceBytesProvider',
	#superclass : 'Object',
	#instVars : [
		'client',
		'repositoryId',
		'fileName',
		'dataOffset'
	],
	#category : 'Gt4GlassCase-HuggingFace',
	#package : 'Gt4GlassCase-HuggingFace'
}

{ #category : 'instance creation' }
GcHuggingFaceBytesProvider class >> client: aClient repositoryId: aRepoId file: aFileName [
	^ self new
		setClient: aClient repositoryId: aRepoId file: aFileName;
		yourself
]

{ #category : 'accessing' }
GcHuggingFaceBytesProvider >> client [
	^ client
]

{ #category : 'accessing' }
GcHuggingFaceBytesProvider >> fileName [
	^ fileName
]

{ #category : 'gt - views' }
GcHuggingFaceBytesProvider >> gtSourceFor: aView [
	"Where does this provider fetch bytes from?"
	<gtView>
	^ aView columnedList
		title: 'Source';
		priority: 1;
		items: [ self sourceFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value isNil ifTrue: [ '-' ] ifFalse: [ assoc value displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'printing' }
GcHuggingFaceBytesProvider >> printOn: aStream [
	aStream
		nextPutAll: 'GcHuggingFaceBytesProvider(';
		nextPutAll: (repositoryId ifNil: [ '?' ]);
		nextPut: $/;
		nextPutAll: (fileName ifNil: [ '?' ]);
		nextPut: $)
]

{ #category : 'bytes port' }
GcHuggingFaceBytesProvider >> provideByteDataOffset [
	"8 + the safetensors header length; read the leading 8 bytes once and cache."
	^ dataOffset ifNil: [
		| first8 |
		first8 := client rangeBytesFrom: self url start: 0 end: 7.
		dataOffset := 8 + (Gt4HuggingFaceClient headerLengthFromBytes: first8) ]
]

{ #category : 'bytes port' }
GcHuggingFaceBytesProvider >> provideBytesFrom: startAbs to: endAbs [
	"Absolute, inclusive byte range via one HTTP Range request. Never fetches weights wholesale (I5) -- callers request small sampled spans only."
	^ client rangeBytesFrom: self url start: startAbs end: endAbs
]

{ #category : 'accessing' }
GcHuggingFaceBytesProvider >> repositoryId [
	^ repositoryId
]

{ #category : 'initialization' }
GcHuggingFaceBytesProvider >> setClient: aClient repositoryId: aRepoId file: aFileName [
	client := aClient.
	repositoryId := aRepoId.
	fileName := aFileName
]

{ #category : 'accessing' }
GcHuggingFaceBytesProvider >> sourceFacets [
	^ {
		'Repository' -> repositoryId.
		'File' -> fileName.
		'URL' -> self url.
		'Data offset' -> dataOffset }
]

{ #category : 'accessing' }
GcHuggingFaceBytesProvider >> url [
	^ client resolveUrlFor: repositoryId file: fileName
]
