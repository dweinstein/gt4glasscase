"
A standalone, provider-focused HuggingFace Hub client built on ZnClient (gt4llm/gt4aws idiom). Returns GENERIC data -- Dictionaries, Strings, ByteArrays, and a Gt4HuggingFaceSafetensorsHeader value object -- and depends on nothing outside this package, so it can be pulled into its own repo and reused. Fetches model info, config.json, the file tree, and the safetensors header via HTTP Range (no weights downloaded). token is injected by the caller (nil = public access).
"
Class {
	#name : 'Gt4HuggingFaceClient',
	#superclass : 'Object',
	#instVars : [
		'baseUrl',
		'token'
	],
	#category : 'Gt4HuggingFace',
	#package : 'Gt4HuggingFace'
}

{ #category : 'safetensors' }
Gt4HuggingFaceClient class >> headerLengthFromBytes: aByteArray [
	"The safetensors header length is a little-endian unsigned 64-bit integer in the first 8 bytes."
	| len |
	len := 0.
	1 to: 8 do: [ :i | len := len + ((aByteArray at: i) * (256 raisedTo: i - 1)) ].
	^ len
]

{ #category : 'urls' }
Gt4HuggingFaceClient >> apiModelUrlFor: aRepoId [
	^ baseUrl, '/api/models/', aRepoId
]

{ #category : 'accessing' }
Gt4HuggingFaceClient >> baseUrl [
	^ baseUrl
]

{ #category : 'accessing' }
Gt4HuggingFaceClient >> baseUrl: aString [
	baseUrl := aString
]

{ #category : 'api' }
Gt4HuggingFaceClient >> config: aRepoId [
	^ self getJson: (self resolveUrlFor: aRepoId file: 'config.json')
]

{ #category : 'api' }
Gt4HuggingFaceClient >> fileTree: aRepoId [
	^ self getJson: (self apiModelUrlFor: aRepoId), '/tree/main'
]

{ #category : 'private' }
Gt4HuggingFaceClient >> getJson: aUrl [
	^ STONJSON fromString: (self getString: aUrl)
]

{ #category : 'private' }
Gt4HuggingFaceClient >> getString: aUrl [
	^ self newClient
		url: aUrl;
		get
]

{ #category : 'testing' }
Gt4HuggingFaceClient >> hasToken [
	^ token notNil and: [ token isEmpty not ]
]

{ #category : 'initialization' }
Gt4HuggingFaceClient >> initialize [
	super initialize.
	baseUrl := 'https://huggingface.co'
]

{ #category : 'api' }
Gt4HuggingFaceClient >> modelInfo: aRepoId [
	^ self getJson: (self apiModelUrlFor: aRepoId)
]

{ #category : 'private' }
Gt4HuggingFaceClient >> newClient [
	| client |
	client := ZnClient new.
	client enforceHttpSuccess: true.
	client timeout: 60.
	self hasToken ifTrue: [ client headerAt: 'Authorization' put: 'Bearer ', token ].
	^ client
]

{ #category : 'printing' }
Gt4HuggingFaceClient >> printOn: aStream [
	aStream nextPutAll: 'Gt4HuggingFaceClient('.
	aStream nextPutAll: (baseUrl ifNil: [ '?' ]).
	self hasToken ifTrue: [ aStream nextPutAll: ' +token' ].
	aStream nextPut: $)
]

{ #category : 'private' }
Gt4HuggingFaceClient >> rangeBytesFrom: aUrl start: startInt end: endInt [
	"A Range GET. 206 Partial Content is the expected success here, so HTTP-success enforcement is disabled and the status is checked explicitly (200 whole-file or 206 partial)."
	| client code |
	client := self newClient.
	client enforceHttpSuccess: false.
	client beBinary.
	client headerAt: 'Range' put: ('bytes=', startInt printString, '-', endInt printString).
	client url: aUrl.
	client get.
	code := client response code.
	(code = 200 or: [ code = 206 ])
		ifFalse: [ self error: 'Unexpected HTTP status ', code printString, ' for ranged GET' ].
	^ client response contents
]

{ #category : 'private' }
Gt4HuggingFaceClient >> rangeBytesIfPresentFrom: aUrl start: startInt end: endInt [
	"A Range GET that returns nil when the file is absent (404), and raises a clear message for gated repos (401/403). Otherwise like rangeBytesFrom:start:end: (200/206 -> bytes)."
	| client code |
	client := self newClient.
	client enforceHttpSuccess: false.
	client beBinary.
	client headerAt: 'Range' put: ('bytes=' , startInt printString , '-' , endInt printString).
	client url: aUrl.
	client get.
	code := client response code.
	(code = 200 or: [ code = 206 ]) ifTrue: [ ^ client response contents ].
	code = 404 ifTrue: [ ^ nil ].
	(code = 401 or: [ code = 403 ]) ifTrue: [
		^ self error: 'gated repo -- a HuggingFace token is required for ' , aUrl ].
	^ self error: 'Unexpected HTTP status ' , code printString , ' for ranged GET'
]

{ #category : 'urls' }
Gt4HuggingFaceClient >> resolveUrlFor: aRepoId file: aFileName [
	^ baseUrl, '/', aRepoId, '/resolve/main/', aFileName
]

{ #category : 'api' }
Gt4HuggingFaceClient >> safetensorsHeader: aRepoId file: aFileName [
	^ Gt4HuggingFaceSafetensorsHeader fromString: (self safetensorsHeaderString: aRepoId file: aFileName)
]

{ #category : 'api' }
Gt4HuggingFaceClient >> safetensorsHeaderString: aRepoId file: aFileName [
	"Fetch only the safetensors header via two HTTP Range requests: the 8-byte little-endian length, then the JSON header. No weights are downloaded (I5)."
	| url first8 headerLength headerBytes |
	url := self resolveUrlFor: aRepoId file: aFileName.
	first8 := self rangeBytesFrom: url start: 0 end: 7.
	headerLength := self class headerLengthFromBytes: first8.
	headerBytes := self rangeBytesFrom: url start: 8 end: 8 + headerLength - 1.
	^ headerBytes utf8Decoded
]

{ #category : 'api - safetensors' }
Gt4HuggingFaceClient >> safetensorsHeaderStringIfPresent: aRepoId file: aFileName [
	"Like safetensorsHeaderString:file: but returns nil when the file is absent (404), so callers can probe for model.safetensors before falling back to the shard index. Raises a clear message for gated repos."
	| url first8 headerLength headerBytes |
	url := self resolveUrlFor: aRepoId file: aFileName.
	first8 := self rangeBytesIfPresentFrom: url start: 0 end: 7.
	first8 ifNil: [ ^ nil ].
	headerLength := self class headerLengthFromBytes: first8.
	headerBytes := self rangeBytesFrom: url start: 8 end: 8 + headerLength - 1.
	^ headerBytes utf8Decoded
]

{ #category : 'api - safetensors' }
Gt4HuggingFaceClient >> safetensorsIndex: aRepoId [
	"The parsed model.safetensors.index.json -- a Dictionary with keys 'weight_map' (tensorName -> shardFile) and 'metadata' (e.g. total_size) -- or nil if the repo has no index (404). Raises a clear message for gated repos. Generic: no Gc types."
	| string |
	string := self safetensorsIndexString: aRepoId.
	^ string ifNotNil: [ STONJSON fromString: string ]
]

{ #category : 'api - safetensors' }
Gt4HuggingFaceClient >> safetensorsIndexString: aRepoId [
	"Fetch model.safetensors.index.json as a String. Returns nil when the repo has no index (404). Raises a clear message for gated repos (401/403). No weights downloaded (I5)."
	| url client code |
	url := self resolveUrlFor: aRepoId file: 'model.safetensors.index.json'.
	client := self newClient.
	client enforceHttpSuccess: false.
	client url: url.
	client get.
	code := client response code.
	code = 200 ifTrue: [ ^ client response contents ].
	code = 404 ifTrue: [ ^ nil ].
	(code = 401 or: [ code = 403 ]) ifTrue: [
		^ self error: 'gated repo -- a HuggingFace token is required for the safetensors index of ' , aRepoId ].
	^ self error: 'Unexpected HTTP status ' , code printString , ' fetching safetensors index for ' , aRepoId
]

{ #category : 'accessing' }
Gt4HuggingFaceClient >> token [
	^ token
]

{ #category : 'accessing' }
Gt4HuggingFaceClient >> token: aString [
	token := aString
]
