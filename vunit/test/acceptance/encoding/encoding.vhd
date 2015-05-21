-- Log package provides the primary functionality of the logging library.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com


-- To test that non ASCII encoded files can be added to the VUnit project
--
--ISO/IEC 8859-1
 --x0	x1	x2	x3	x4	x5	x6	x7	x8	x9	xA	xB	xC	xD	xE	xF
 --0x
 --1x
 --2x	SP	!	"	#	$	%	&	'	(	)	*	+	,	-	.	/
 --3x	0	1	2	3	4	5	6	7	8	9	:	;	<	=	>	?
 --4x	@	A	B	C	D	E	F	G	H	I	J	K	L	M	N	O
 --5x	P	Q	R	S	T	U	V	W	X	Y	Z	[	\	]	^	_
 --6x	`	a	b	c	d	e	f	g	h	i	j	k	l	m	n	o
 --7x	p	q	r	s	t	u	v	w	x	y	z	{	|	}	~
 --8x
 --9x
 --Ax	NBSP	¡	¢	£	¤	¥	¦	§	¨	©	ª	«	¬	SHY	®	¯
 --Bx	°	±	²	³	´	µ	¶	·	¸	¹	º	»	¼	½	¾	¿
 --Cx	À	Á	Â	Ã	Ä	Å	Æ	Ç	È	É	Ê	Ë	Ì	Í	Î	Ï
 --Dx	Ð	Ñ	Ò	Ó	Ô	Õ	Ö	×	Ø	Ù	Ú	Û	Ü	Ý	Þ	ß
 --Ex	à	á	â	ã	ä	å	æ	ç	è	é	ê	ë	ì	í	î	ï
 --Fx	ð	ñ	ò	ó	ô	õ	ö	÷	ø	ù	ú	û	ü	ý	þ	ÿ

entity encoding is
end entity;

architecture a of encoding is
begin
end architecture;
