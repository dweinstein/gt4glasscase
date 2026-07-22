"
Stage D BEHAVIORAL concept probing (one word). Instead of reading a concept's geometry from static embeddings (Stages A-C), it asks the RUNNING GPT-2 what a word IS: it fills a hypernym completion `template` (default 'A {word} is a kind of') with `word`, encodes the resulting `promptText` to `promptIds` (GcTokenizer gpt2), runs ONE short forward pass over the model (via the KV-cache prefill path with a FRESH GcKvCache, leaving the shared model uncorrupted), and reads the last-position logits through softmax to the top-k predicted NEXT tokens. Reuses the linear O(n*k) top-k idiom from GcLogitLens (NEVER asSortedCollection over the 50k vocab), producing GcLogitLensEntry objects decoded via GcGpt2Decoder default. run answers a GcConceptProbeResult. This is how the model USES the concept, not where it sits in embedding space.
"
Class {
	#name : 'GcConceptProbe',
	#superclass : 'Object',
	#instVars : [
		'template',
		'word',
		'model',
		'topK'
	],
	#category : 'Gt4GlassCase-Behavioral',
	#package : 'Gt4GlassCase',
	#tag : 'Behavioral'
}

{ #category : 'accessing' }
GcConceptProbe class >> defaultTemplate [
	"The hypernym completion template; {word} is the fill point. Ends at 'of' (no trailing space) so the predicted next token is a leading-space category word, matching the concept member-word convention."
	^ 'A {word} is a kind of'
]

{ #category : 'instance creation' }
GcConceptProbe class >> word: aWord [
	"Probe aWord with the default template over the shared default GPT-2 model."
	^ self word: aWord template: self defaultTemplate model: GcGpt2Model default
]

{ #category : 'instance creation' }
GcConceptProbe class >> word: aWord template: aTemplate model: aModel [
	^ self new setWord: aWord template: aTemplate model: aModel
]

{ #category : 'gt - views' }
GcConceptProbe >> gtDetailsFor: aView [
	<gtView>
	"The probe setup (no model run): word, template, filled prompt and its token ids."
	^ aView columnedList
		title: 'Probe';
		priority: 10;
		items: [ {
			'word' -> (word ifNil: [ '?' ]).
			'template' -> self template.
			'prompt' -> self promptText.
			'prompt ids' -> self promptIds printString.
			'top-k' -> self topK printString } ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ]
]

{ #category : 'accessing' }
GcConceptProbe >> model [
	^ model
]

{ #category : 'accessing' }
GcConceptProbe >> model: aModel [
	model := aModel
]

{ #category : 'printing' }
GcConceptProbe >> printOn: aStream [
	aStream nextPutAll: self class name; nextPutAll: '('; nextPutAll: (word ifNil: [ '?' ]); nextPutAll: ')'
]

{ #category : 'accessing' }
GcConceptProbe >> promptIds [
	"The prompt text encoded with the MODEL'S tokenizer (no network). Asking the model -- not the global gpt2 tokenizer -- keeps the probe correct for any model whose vocabulary differs."
	^ model tokenizer encode: self promptText
]

{ #category : 'probing' }
GcConceptProbe >> promptText [
	"The template with {word} replaced by the probed word, e.g. 'A dog is a kind of'."
	^ self template copyReplaceAll: '{word}' with: word
]

{ #category : 'probing' }
GcConceptProbe >> run [
	"Run ONE short forward pass over the prompt (KV-cache prefill with a FRESH cache -- leaves the shared model uncorrupted), softmax the last-position logits, and answer a GcConceptProbeResult holding the top-k predicted next tokens."
	| ids cache logits probs entries |
	ids := self promptIds.
	cache := GcKvCache new numLayers: model numLayers.
	logits := model prefillTokenIds: ids cache: cache.
	probs := GcTensorMath softmax: logits.
	entries := self topEntriesFromLogits: logits probs: probs k: self topK.
	^ GcConceptProbeResult word: word template: self template entries: entries
]

{ #category : 'initialization' }
GcConceptProbe >> setWord: aWord template: aTemplate model: aModel [
	word := aWord.
	template := aTemplate.
	model := aModel
]

{ #category : 'accessing' }
GcConceptProbe >> template [
	^ template ifNil: [ template := self class defaultTemplate ]
]

{ #category : 'accessing' }
GcConceptProbe >> template: aTemplate [
	template := aTemplate
]

{ #category : 'private' }
GcConceptProbe >> topEntriesFromLogits: logitsArray probs: probsArray k: k [
	"The k highest-logit tokens as GcLogitLensEntry objects, most likely first. Linear top-k selection (O(n*k)) reusing the GcLogitLens idiom -- NEVER asSortedCollection over the 50k vocab. Decodes ids via the MODEL'S decoder (not a global) so other-vocab models label tokens correctly."
	| best decoder |
	best := OrderedCollection new.
	1 to: logitsArray size do: [ :i |
		| v |
		v := logitsArray at: i.
		(best size < k or: [ v > (logitsArray at: best last) ]) ifTrue: [
			| inserted |
			inserted := false.
			1 to: best size do: [ :j |
				(inserted not and: [ v > (logitsArray at: (best at: j)) ]) ifTrue: [
					best add: i beforeIndex: j.
					inserted := true ] ].
			inserted ifFalse: [ best addLast: i ].
			best size > k ifTrue: [ best removeLast ] ] ].
	decoder := model decoder.
	^ best withIndexCollect: [ :idx :r |
		| id |
		id := idx - 1.
		GcLogitLensEntry
			rank: r
			tokenId: id
			tokenText: (decoder decodeId: id)
			logit: (logitsArray at: idx)
			prob: (probsArray at: idx) ]
]

{ #category : 'accessing' }
GcConceptProbe >> topK [
	"How many predicted next tokens to keep, most likely first."
	^ topK ifNil: [ 5 ]
]

{ #category : 'accessing' }
GcConceptProbe >> topK: anInteger [
	topK := anInteger
]

{ #category : 'accessing' }
GcConceptProbe >> word [
	^ word
]

{ #category : 'accessing' }
GcConceptProbe >> word: aWord [
	word := aWord
]
