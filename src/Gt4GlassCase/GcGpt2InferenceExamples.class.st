"
gtExample methods proving the GPT-2 forward pass and greedy generation against the real openai-community/gpt2 weights in the local glassbox cache. decodeFixturePromptExample is a plain automated example (reads only vocab.json). The end-to-end examples are <noTest> because they load ~500MB of weights and run compute-heavy forwards: singleShotCapitalOfFranceExample documents the model's genuine single-shot behavior, while inContextGreedyParisExample, capitalAnalogyBerlinExample and continuationDemoExample prove genuine ' Paris' / ' Berlin' greedy outcomes from in-context prompts.
"
Class {
	#name : 'GcGpt2InferenceExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'asserting' }
GcGpt2InferenceExamples >> assert: actual equals: expected [
	actual = expected ifFalse: [ self error: 'expected ', expected printString, ' but got ', actual printString ]
]

{ #category : 'asserting' }
GcGpt2InferenceExamples >> assertTrue: aBoolean [
	aBoolean ifFalse: [ self error: 'assertion failed' ]
]

{ #category : 'examples' }
GcGpt2InferenceExamples >> capitalAnalogyBerlinExample [
	<gtExample>
	<noTest>
	"A stronger faithfulness proof of the forward pass: 'The capital of France is Paris. The capital of Germany is' greedily predicts ' Berlin' (id 11307) as the #1 next token (its top-5 are all German cities). A one-shot analogy a buggy forward could not produce -- strong evidence the GPT-2 forward pass is correct."
	| model ids logits greedyId decoded result |
	model := GcGpt2Model default.
	ids := self germanyAnalogyPromptIds.
	logits := model forwardTokenIds: ids.
	greedyId := GcTensorMath argmax: logits.
	decoded := GcGpt2Decoder default decodeId: greedyId.
	result := Dictionary new.
	result at: #greedyId put: greedyId; at: #decoded put: decoded; at: #logitsSize put: logits size.
	self assert: logits size equals: 50257.
	self assert: greedyId equals: 11307.
	self assert: decoded equals: ' Berlin'.
	^ result
]

{ #category : 'prompts' }
GcGpt2InferenceExamples >> capitalOfFrancePromptIds [
	"Token ids for 'The capital of France is' (the bare zero-shot prompt)."
	^ #(464 3139 286 4881 318)
]

{ #category : 'examples' }
GcGpt2InferenceExamples >> continuationDemoExample [
	<gtExample>
	<noTest>
	"The outcome jump: greedy MULTI-token generation. From 'The capital of France is Paris. The capital of France is', greedily generate 8 tokens; the continuation begins with ' Paris'. Uses the in-context prompt so the demonstrated ' Paris' continuation is a genuine model outcome (GPT-2-124M is too weak to produce it zero-shot; see singleShotCapitalOfFranceExample). Returns the GcGeneration (open its Tokens / Text views)."
	| model gen continuation |
	model := GcGpt2Model default.
	gen := model generateFromTokenIds: self franceInContextPromptIds maxTokens: 8.
	continuation := gen generatedText.
	self assert: gen generatedIds size equals: 8.
	self assertTrue: (continuation beginsWith: ' Paris').
	^ gen
]

{ #category : 'examples' }
GcGpt2InferenceExamples >> decodeFixturePromptExample [
	<gtExample>
	"Decode the fixed GPT-2 token ids for 'The capital of France is' and assert the exact string. Reads only vocab.json -- deterministic, no weights, so this joins the automated suite."
	| decoded |
	decoded := GcGpt2Decoder default decodeIds: #(464 3139 286 4881 318).
	self assert: decoded equals: 'The capital of France is'.
	^ decoded
]

{ #category : 'prompts' }
GcGpt2InferenceExamples >> franceInContextPromptIds [
	"Token ids for 'The capital of France is Paris. The capital of France is' -- the fact stated once, then re-primed, so greedy induction yields ' Paris'."
	^ #(464 3139 286 4881 318 6342 13 383 3139 286 4881 318)
]

{ #category : 'prompts' }
GcGpt2InferenceExamples >> germanyAnalogyPromptIds [
	"Token ids for 'The capital of France is Paris. The capital of Germany is' -- a one-shot analogy whose greedy answer is ' Berlin'."
	^ #(464 3139 286 4881 318 6342 13 383 3139 286 4486 318)
]

{ #category : 'examples' }
GcGpt2InferenceExamples >> inContextGreedyParisExample [
	<gtExample>
	<noTest>
	"The genuine ' Paris' greedy outcome. Prompt: 'The capital of France is Paris. The capital of France is'. With the fact given in-context, GPT-2-124M greedily and unambiguously predicts ' Paris' (id 6342) as the #1 next token. This proves the forward pass + greedy argmax end-to-end on a real ' Paris' outcome (a faithful demonstration, since the bare zero-shot prompt exceeds GPT-2-small's factual recall -- see singleShotCapitalOfFranceExample)."
	| model ids logits ms greedyId decoded result |
	model := GcGpt2Model default.
	ids := self franceInContextPromptIds.
	ms := [ logits := model forwardTokenIds: ids ] millisecondsToRun.
	greedyId := GcTensorMath argmax: logits.
	decoded := GcGpt2Decoder default decodeId: greedyId.
	result := Dictionary new.
	result at: #forwardMs put: ms; at: #greedyId put: greedyId; at: #decoded put: decoded; at: #logitsSize put: logits size.
	self assert: logits size equals: 50257.
	self assert: greedyId equals: 6342.
	self assert: decoded equals: ' Paris'.
	^ result
]

{ #category : 'examples' }
GcGpt2InferenceExamples >> singleShotCapitalOfFranceExample [
	<gtExample>
	<noTest>
	"Forward the bare zero-shot prompt 'The capital of France is' through the real GPT-2-124M weights and document the model's genuine single-shot behavior: the greedy top token is ' the' -- GPT-2-small is too weak to place ' Paris' first zero-shot -- yet ' Paris' (id 6342) sits within the top-5, so the fact IS represented. Asserts logits size 50257 and that ' Paris' is in the top-5. (The genuine ' Paris' / ' Berlin' greedy outcomes are proven by inContextGreedyParisExample and capitalAnalogyBerlinExample.)"
	| model ids logits ms greedyId top5 result |
	model := GcGpt2Model default.
	ids := self capitalOfFrancePromptIds.
	ms := [ logits := model forwardTokenIds: ids ] millisecondsToRun.
	greedyId := GcTensorMath argmax: logits.
	top5 := self topKIdsFor: logits k: 5.
	result := Dictionary new.
	result
		at: #forwardMs put: ms;
		at: #greedyId put: greedyId;
		at: #greedyPiece put: (GcGpt2Decoder default decodeId: greedyId);
		at: #top5 put: (top5 collect: [ :id | id -> (GcGpt2Decoder default decodeId: id) ]);
		at: #parisRank put: (top5 indexOf: 6342);
		at: #logitsSize put: logits size.
	self assert: logits size equals: 50257.
	self assertTrue: (top5 includes: 6342).
	^ result
]

{ #category : 'asserting' }
GcGpt2InferenceExamples >> topKIdsFor: logits k: k [
	"The token ids of the k largest logits, highest first."
	| pairs |
	pairs := (1 to: logits size) collect: [ :i | (i - 1) -> (logits at: i) ].
	^ ((pairs asSortedCollection: [ :a :b | a value > b value ]) first: k) collect: [ :a | a key ]
]
