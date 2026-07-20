"
A token suspected undertrained on embedding-weight evidence (glitch-token / SolidGoldMagikarp family, DW-19). WRAPS a GcVocabToken (an undertrained token IS a vocab token plus an embedding-norm verdict) and delegates id / text / hexBytes / flags to it, adding the weight evidence:
- embeddingNorm: L2 norm of the token's embedding row.
- unembeddingNorm: = embeddingNorm when the output projection is TIED (no separate lm_head tensor), the lm_head row norm when untied, nil when unknown.
- tied: whether the output projection is tied (honest provenance for unembeddingNorm).
- centroidDistance: Euclidean distance from the control-band centroid (an approximation of the true embedding centroid).
- mergeRank: nil until DW-18 parses the BPE merge list (merge-rank belongs to the next task).
- score / normScore / centroidScore: the composite suspicion score and its two components.

Score (higher = more undertrained-looking, range [0,1]):
    score = 0.5*normScore + 0.5*centroidScore
where
    normScore     = fraction of control-band tokens whose embedding norm EXCEEDS this token's (a token smaller-normed than most typical tokens scores ~1),
    centroidScore = fraction of control-band tokens FARTHER from the centroid than this token (a token nearer the centroid than most scores ~1).
Both are control-band percentiles, so the score is rank-normalized and scale-free. See GcUndertrainedScan for the detector and provenance; asTrigger maps it to a Phase-5 GcTrigger candidate.
"
Class {
	#name : 'GcUndertrainedToken',
	#superclass : 'Object',
	#instVars : [
		'vocabToken',
		'embeddingNorm',
		'unembeddingNorm',
		'tied',
		'centroidDistance',
		'mergeRank',
		'score',
		'normScore',
		'centroidScore'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcUndertrainedToken class >> vocabToken: aVocabToken embeddingNorm: eNorm unembeddingNorm: uNorm tied: aBool centroidDistance: aDist normScore: nScore centroidScore: cScore score: aScore [
	^ self new
		vocabToken: aVocabToken;
		embeddingNorm: eNorm;
		unembeddingNorm: uNorm;
		tied: aBool;
		centroidDistance: aDist;
		normScore: nScore;
		centroidScore: cScore;
		score: aScore;
		yourself
]

{ #category : 'converting' }
GcUndertrainedToken >> asTrigger [
	"Phase-5 handoff: this undertrained token as a candidate GcTrigger inserted as a prefix token."
	^ GcTrigger form: #token content: self text position: #prefix
]

{ #category : 'accessing' }
GcUndertrainedToken >> centroidDistance [
	^ centroidDistance
]

{ #category : 'accessing' }
GcUndertrainedToken >> centroidDistance: aNumber [
	centroidDistance := aNumber
]

{ #category : 'accessing' }
GcUndertrainedToken >> centroidScore [
	^ centroidScore
]

{ #category : 'accessing' }
GcUndertrainedToken >> centroidScore: aNumber [
	centroidScore := aNumber
]

{ #category : 'accessing' }
GcUndertrainedToken >> detailFacets [
	"Why is this token suspicious? Every field the auditor needs, provenance-honest."
	^ {
		'Token' -> self text.
		'Rendered' -> self text printString.
		'Id' -> self tokenId.
		'UTF-8 bytes' -> self hexBytes.
		'Embedding L2 norm' -> self embeddingNorm.
		'Unembedding L2 norm' -> (self unembeddingNorm ifNil: [ 'n/a' ]).
		'Output tied?' -> (self tied isNil ifTrue: [ 'unknown' ] ifFalse: [ self tied ]).
		'Distance to centroid' -> self centroidDistance.
		'Merge rank' -> (self mergeRank ifNil: [ 'unknown (DW-18)' ]).
		'Norm percentile score' -> self normScore.
		'Centroid percentile score' -> self centroidScore.
		'Suspicion score' -> self score.
		'Metadata flags' -> self vocabToken flagsString }
]

{ #category : 'accessing' }
GcUndertrainedToken >> embeddingNorm [
	^ embeddingNorm
]

{ #category : 'accessing' }
GcUndertrainedToken >> embeddingNorm: aNumber [
	embeddingNorm := aNumber
]

{ #category : 'gt views' }
GcUndertrainedToken >> gtWhySuspiciousFor: aView [
	<gtView>
	"Why is this token suspicious? The embedding-weight evidence, byte by byte."
	^ aView columnedList
		title: 'Why suspicious?';
		priority: 1;
		items: [ self detailFacets ];
		column: 'Facet' text: [ :assoc | assoc key asString ];
		column: 'Value' text: [ :assoc |
			| v |
			v := assoc value.
			v isNil
				ifTrue: [ '-' ]
				ifFalse: [ (v isCollection and: [ v isString not ])
					ifTrue: [ v printString ]
					ifFalse: [ v displayString ] ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'delegation' }
GcUndertrainedToken >> hexBytes [
	"Byte-level rendering of the token text, so unprintable / byte-level-BPE tokens are legible."
	^ vocabToken hexBytes
]

{ #category : 'accessing' }
GcUndertrainedToken >> mergeRank [
	^ mergeRank
]

{ #category : 'accessing' }
GcUndertrainedToken >> mergeRank: anIntegerOrNil [
	mergeRank := anIntegerOrNil
]

{ #category : 'accessing' }
GcUndertrainedToken >> normScore [
	^ normScore
]

{ #category : 'accessing' }
GcUndertrainedToken >> normScore: aNumber [
	normScore := aNumber
]

{ #category : 'printing' }
GcUndertrainedToken >> printOn: aStream [
	aStream nextPutAll: 'undertrained '; print: self text.
	embeddingNorm ifNotNil: [ :n |
		aStream nextPutAll: ' norm='; nextPutAll: (n asFloat printShowingDecimalPlaces: 4) ].
	score ifNotNil: [ :s |
		aStream nextPutAll: ' score='; nextPutAll: (s asFloat printShowingDecimalPlaces: 3) ]
]

{ #category : 'accessing' }
GcUndertrainedToken >> score [
	^ score
]

{ #category : 'accessing' }
GcUndertrainedToken >> score: aNumber [
	score := aNumber
]

{ #category : 'delegation' }
GcUndertrainedToken >> text [
	^ vocabToken text
]

{ #category : 'accessing' }
GcUndertrainedToken >> tied [
	^ tied
]

{ #category : 'accessing' }
GcUndertrainedToken >> tied: aBooleanOrNil [
	tied := aBooleanOrNil
]

{ #category : 'delegation' }
GcUndertrainedToken >> tokenId [
	^ vocabToken tokenId
]

{ #category : 'accessing' }
GcUndertrainedToken >> unembeddingNorm [
	^ unembeddingNorm
]

{ #category : 'accessing' }
GcUndertrainedToken >> unembeddingNorm: aNumberOrNil [
	unembeddingNorm := aNumberOrNil
]

{ #category : 'accessing' }
GcUndertrainedToken >> vocabToken [
	^ vocabToken
]

{ #category : 'accessing' }
GcUndertrainedToken >> vocabToken: aGcVocabToken [
	vocabToken := aGcVocabToken
]
