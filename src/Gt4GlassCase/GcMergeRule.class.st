"
One entry of a BPE merge list (DW-18): the ordered rule that fuses a left piece and a right piece into the merged piece (left , right) at a 0-based rank. The ordered list of these rules is a fingerprint of the tokenizer's training corpus -- rank 0 is the most frequent byte pair, rank n-1 the least. Pieces are the tokenizer's own piece strings, so byte-level-BPE space renders as the marker U+0120 and newline as U+010A. Stores left/right/rank; merged and pair are derived. Corpus-free derived facts: producedCategory classifies the merged piece (#whitespace #digit #asciiLetter #punctuation #cjk #otherNonAscii, mapping leading byte-level whitespace markers to whitespace context; see #producedCategory), isWhitespaceRun flags a run of >=2 whitespace/marker chars, and displayMerged/displayPair show \\xHH hex for raw unprintables. No frequency is available without the corpus, so anything needing counts belongs to the Python Tier-2 oracle, not here.
"
Class {
	#name : 'GcMergeRule',
	#superclass : 'Object',
	#instVars : [
		'rank',
		'left',
		'right'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'constants' }
GcMergeRule class >> categories [
	"The closed set of produced-token categories, in a fixed display order."
	^ #(#whitespace #digit #asciiLetter #punctuation #cjk #otherNonAscii)
]

{ #category : 'instance creation' }
GcMergeRule class >> left: aString right: bString rank: anInteger [
	^ self new setLeft: aString right: bString rank: anInteger
]

{ #category : 'accessing' }
GcMergeRule >> detailFacets [
	^ {
		'Rank' -> self rank.
		'Left piece' -> (self displayStringOf: left).
		'Right piece' -> (self displayStringOf: right).
		'Merged' -> self displayMerged.
		'UTF-8 bytes' -> self hexBytes.
		'Category' -> self producedCategory.
		'Whitespace run?' -> self isWhitespaceRun.
		'Degenerate pair?' -> self isDegeneratePair }
]

{ #category : 'displaying' }
GcMergeRule >> displayMerged [
	^ self displayStringOf: self merged
]

{ #category : 'displaying' }
GcMergeRule >> displayPair [
	^ (self displayStringOf: left) , ' + ' , (self displayStringOf: right)
]

{ #category : 'displaying' }
GcMergeRule >> displayStringOf: aString [
	"Printable rendering: raw control / U+FFFD chars shown as \xHH over their UTF-8 bytes; everything else (including byte-level markers) verbatim."
	| stream |
	stream := WriteStream on: String new.
	aString do: [ :ch |
		(ch asInteger < 32 or: [ ch asInteger = 127 or: [ ch asInteger = 16rFFFD ] ])
			ifTrue: [ ch asString utf8Encoded do: [ :b |
				stream nextPutAll: '\x'; nextPutAll: (b printPaddedWith: $0 to: 2 base: 16) ] ]
			ifFalse: [ stream nextPut: ch ] ].
	^ stream contents
]

{ #category : 'gt views' }
GcMergeRule >> gtFacetsFor: aView [
	<gtView>
	"What exactly does this merge produce, and how is it classified?"
	^ aView columnedList
		title: 'Facets';
		priority: 1;
		items: [ self detailFacets ];
		column: 'Facet' text: [ :assoc | assoc key asString ];
		column: 'Value' text: [ :assoc | assoc value displayString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'accessing' }
GcMergeRule >> hexBytes [
	^ self merged utf8Encoded hex
]

{ #category : 'private' }
GcMergeRule >> isAsciiLetter: aCharacter [
	^ aCharacter asInteger < 128 and: [ aCharacter isLetter ]
]

{ #category : 'private' }
GcMergeRule >> isCjkChar: aCharacter [
	| cp |
	cp := aCharacter asInteger.
	^ (cp between: 16r3040 and: 16r30FF)
		or: [ (cp between: 16r3400 and: 16r4DBF)
		or: [ (cp between: 16r4E00 and: 16r9FFF)
		or: [ (cp between: 16rAC00 and: 16rD7A3)
		or: [ cp between: 16rF900 and: 16rFAFF ] ] ] ]
]

{ #category : 'classifying' }
GcMergeRule >> isDegeneratePair [
	"Are the two merged pieces identical? A duplicate/degenerate pair is a weak hand-insertion signal."
	^ left = right
]

{ #category : 'private' }
GcMergeRule >> isWhitespaceContextChar: aCharacter [
	"A whitespace/space-marker character: a real separator, OR a byte-level BPE marker for a control/space byte (bytes 0..32 map to U+0100..U+0120)."
	^ aCharacter isSeparator or: [ aCharacter asInteger between: 256 and: 288 ]
]

{ #category : 'classifying' }
GcMergeRule >> isWhitespaceRun [
	"Is the merged piece a run of >=2 whitespace / byte-level whitespace-marker characters? A hand-inserted indentation/space token looks like this (the paper flags Gemma's space merges)."
	| str |
	str := self merged.
	^ str size >= 2 and: [ str allSatisfy: [ :ch | self isWhitespaceContextChar: ch ] ]
]

{ #category : 'accessing' }
GcMergeRule >> left [
	^ left
]

{ #category : 'accessing' }
GcMergeRule >> merged [
	"The piece produced by this merge: the concatenation of the two pieces."
	^ left , right
]

{ #category : 'accessing' }
GcMergeRule >> pair [
	"The two merged pieces as a domain-meaningful 2-element array."
	^ { left. right }
]

{ #category : 'printing' }
GcMergeRule >> printOn: aStream [
	aStream
		nextPutAll: 'merge #';
		print: rank;
		nextPutAll: ' ';
		nextPutAll: (self displayStringOf: left);
		nextPutAll: '+';
		nextPutAll: (self displayStringOf: right);
		nextPutAll: ' -> ';
		nextPutAll: self displayMerged
]

{ #category : 'classifying' }
GcMergeRule >> producedCategory [
	"Classify the merged piece into one documented category. Leading byte-level whitespace/control markers (U+0100..U+0120, i.e. bytes 0..32 in byte-level BPE) are stripped first and treated as whitespace context, so 'Gthe' classifies on 'the'. An all-whitespace/marker piece is #whitespace. The first remaining content char decides: ASCII digit => #digit, ASCII letter => #asciiLetter, CJK => #cjk, other printable ASCII (33..126) => #punctuation, anything else non-ASCII => #otherNonAscii."
	| str content first |
	str := self merged.
	content := str.
	[ content notEmpty and: [ self isWhitespaceContextChar: content first ] ]
		whileTrue: [ content := content allButFirst ].
	content isEmpty ifTrue: [ ^ #whitespace ].
	first := content first.
	(first asInteger < 128 and: [ first isDigit ]) ifTrue: [ ^ #digit ].
	(self isAsciiLetter: first) ifTrue: [ ^ #asciiLetter ].
	(self isCjkChar: first) ifTrue: [ ^ #cjk ].
	first asInteger < 128 ifTrue: [ ^ #punctuation ].
	^ #otherNonAscii
]

{ #category : 'classifying' }
GcMergeRule >> producesControlCharacter [
	"Does the merged piece contain a RAW control character (codepoint < 32 or = 127)? Byte-level markers (U+0100..) are not raw controls and do not count."
	^ self merged anySatisfy: [ :ch | ch asInteger < 32 or: [ ch asInteger = 127 ] ]
]

{ #category : 'accessing' }
GcMergeRule >> rank [
	^ rank
]

{ #category : 'accessing' }
GcMergeRule >> right [
	^ right
]

{ #category : 'initialization' }
GcMergeRule >> setLeft: aString right: bString rank: anInteger [
	left := aString.
	right := bString.
	rank := anInteger
]
