SuperStrict

Framework brl.standardio
Import koriolis.zipstream

Local books:String[] = ["LegendsOfTheGods.txt", "MythsAndLegendsOfAncientGreeceAndRome.txt", "MythsAndLegendsOfChina.txt"]

For Local book:String = EachIn books

	Local text:String = LoadText("zip::books.zip//" + book)

	Print book
	Print "   Size : " + text.length

	Print ""

Next
