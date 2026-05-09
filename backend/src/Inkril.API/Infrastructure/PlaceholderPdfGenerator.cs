using System.Text;

namespace Inkril.API.Infrastructure;

/// <summary>
/// Generates multi-page placeholder PDFs with real public-domain text excerpts.
/// Runs at startup — idempotent, skips files that already exist.
/// </summary>
public static class PlaceholderPdfGenerator
{
    public static void Generate(string uploadsRoot)
    {
        var booksDir = Path.Combine(uploadsRoot, "books");
        Directory.CreateDirectory(booksDir);

        foreach (var book in Books)
        {
            var path = Path.Combine(booksDir, book.Filename);
            if (File.Exists(path)) File.Delete(path); // regenerate with new content
            File.WriteAllBytes(path, BuildPdf(book));
        }
    }

    // ── Book content ──────────────────────────────────────────────────────────

    private static readonly BookContent[] Books =
    [
        new(
            "moby-dick.pdf",
            "Moby Dick",
            "Herman Melville",
            [
                // Page 1
                "CHAPTER 1 — Loomings\n\n" +
                "Call me Ishmael. Some years ago — never mind how long precisely — having\n" +
                "little or no money in my purse, and nothing particular to interest me on shore,\n" +
                "I thought I would sail about a little and see the watery part of the world.\n" +
                "It is a way I have of driving off the spleen and regulating the circulation.\n" +
                "Whenever I find myself growing grim about the mouth; whenever it is a damp,\n" +
                "drizzly November in my soul; whenever I find myself involuntarily pausing\n" +
                "before coffin warehouses, and bringing up the rear of every funeral I meet;\n" +
                "and especially whenever my hypos get such an upper hand of me, that it\n" +
                "requires a strong moral principle to prevent me from deliberately stepping\n" +
                "into the street, and methodically knocking people's hats off — then, I account\n" +
                "it high time to get to sea as soon as I can.",

                // Page 2
                "This is my substitute for pistol and ball. With a philosophical flourish Cato\n" +
                "throws himself upon his sword; I quietly take to the ship. There is nothing\n" +
                "surprising in this. If they only knew it, almost all men in their degree, some\n" +
                "time or other, cherish very nearly the same feelings towards the ocean with me.\n\n" +
                "There now is your insular city of the Manhattoes, belted round by wharves as\n" +
                "Indian isles by coral reefs — commerce surrounds it with her surf. Right and\n" +
                "left, the streets take you waterward. Its extreme downtown is the battery,\n" +
                "where that noble mole is washed by waves, and cooled by breezes, which a few\n" +
                "hours previous were out of sight of land. Look at the crowds of water-gazers\n" +
                "there. Circumambulate the city of a dreamy Sabbath afternoon.",

                // Page 3
                "CHAPTER 2 — The Carpet-Bag\n\n" +
                "I stuffed a shirt or two into my old carpet-bag, tucked it under my arm, and\n" +
                "started for Cape Horn and the Pacific. Quitting the good city of old Manhatto,\n" +
                "I duly arrived in New Bedford. It was a Saturday night in December. Much was\n" +
                "I disappointed upon learning that the little packet for Nantucket had already\n" +
                "sailed, and that no way of reaching that place would offer itself till the\n" +
                "following Monday.\n\n" +
                "As most young candidates for the pains and penalties of whaling stop at this\n" +
                "same New Bedford, thence to embark on their voyage, it may as well be related\n" +
                "that I, for one, had no idea of so doing. For my mind was made up to sail in\n" +
                "no other than a Nantucket craft, because there was a fine, boisterous something\n" +
                "about everything connected with that famous old island.",

                // Page 4
                "CHAPTER 3 — The Spouter-Inn\n\n" +
                "Entering that gable-ended Spouter-Inn, you found yourself in a wide, low,\n" +
                "straggling entry with old-fashioned wainscots, reminding one of the bulwarks\n" +
                "of some condemned old craft. On one side hung a very large oil painting so\n" +
                "thoroughly besmoked, and every way defaced, that in the unequal crosslights\n" +
                "by which you viewed it, it was only by diligent study and a series of\n" +
                "systematic visits to it, and careful inquiry of the neighbors, that you could\n" +
                "any way arrive at an understanding of its purpose.\n\n" +
                "Such unaccountable masses of shades and shadows, that at first you almost\n" +
                "thought some ambitious young artist had endeavored to delineate chaos bewitched.",

                // Page 5
                "CHAPTER 36 — The Quarter-Deck\n\n" +
                "\"What do ye do when ye see a whale, men?\"\n" +
                "\"Sing out for him!\" was the impulsive rejoinder from a score of clubbed voices.\n\n" +
                "\"Good!\" cried Ahab, with a wild approval in his tones; observing the hearty\n" +
                "animation into which his unexpected question had so magnetically thrown them.\n\n" +
                "\"And what do ye next, men?\"\n\n" +
                "\"Lower away, and after him!\"\n\n" +
                "\"And what tune is it ye pull to, men?\"\n\n" +
                "\"A dead whale or a stove boat!\"\n\n" +
                "More and more strangely and fiercely glad and approving, grew the countenance\n" +
                "of the old man at every shout; while the mariners began to gaze curiously at\n" +
                "each other, as if marvelling how it was that they themselves became so excited\n" +
                "at such seemingly purposeless questions.",

                // Page 6
                "\"I, Ishmael, was one of that crew; my shouts had gone up with the rest;\n" +
                "my oath had been welded with theirs; and stronger I shouted, and more did I\n" +
                "hammer and clinch my oath, because of the dread in my soul. A wild, mystical,\n" +
                "sympathetical feeling was in me; Ahab's quenchless feud seemed mine. With\n" +
                "greedy ears I learned the history of that murderous monster against whom I\n" +
                "and all the others had taken our oaths of violence and revenge.\"\n\n" +
                "For some time past, though at intervals only, the unaccompanied, secluded White\n" +
                "Whale had haunted those uncivilized seas mostly frequented by the Sperm Whale\n" +
                "fishermen. But not all of them knew of his existence; only a few of them, as\n" +
                "yet, had heard of the White Whale, knew of the White Whale, gazed on the White\n" +
                "Whale. The White Whale — Moby Dick.",
            ]
        ),

        new(
            "1984.pdf",
            "Nineteen Eighty-Four",
            "George Orwell",
            [
                // Page 1
                "PART ONE — I\n\n" +
                "It was a bright cold day in April, and the clocks were striking thirteen.\n" +
                "Winston Smith, his chin nuzzled into his breast in an effort to escape the\n" +
                "vile wind, slipped quickly through the glass doors of Victory Mansions,\n" +
                "though not quickly enough to prevent a swirl of gritty dust from entering\n" +
                "along with him.\n\n" +
                "The hallway smelt of boiled cabbage and old rag mats. At one end of it a\n" +
                "coloured poster, too large for the interior, had been tacked to the wall.\n" +
                "It depicted simply an enormous face, more than a metre wide: the face of a\n" +
                "man of about forty-five, with a heavy black moustache and ruggedly handsome\n" +
                "features. Winston made for the stairs. It was no use trying the lift.",

                // Page 2
                "On each landing, opposite the lift shaft, the poster with the enormous face\n" +
                "gazed from the wall. It was one of those pictures which are so contrived that\n" +
                "the eyes follow you about when you move. BIG BROTHER IS WATCHING YOU, the\n" +
                "caption beneath it ran.\n\n" +
                "Inside the flat a fruity voice was reading out a list of figures which had\n" +
                "something to do with the production of pig-iron. The voice came from an oblong\n" +
                "metal plaque like a dulled mirror which formed part of the surface of the\n" +
                "right-hand wall. Winston turned a switch and the voice sank somewhat, though\n" +
                "the words were still distinguishable. The instrument (the telescreen, it was\n" +
                "called) could be dimmed, but there was no way of shutting it off completely.\n\n" +
                "He moved over to the window: a smallish, frail figure, the meagreness of his\n" +
                "body merely emphasized by the blue overalls which were the uniform of the party.",

                // Page 3
                "Outside, even through the shut window-pane, the world looked cold. Down in\n" +
                "the street little eddies of wind were whirling dust and torn paper into spirals,\n" +
                "and though the sun was shining and the sky a harsh blue, there seemed to be\n" +
                "no colour in anything, except the posters that were plastered everywhere.\n\n" +
                "The black-moustachio'd face gazed down from every commanding corner. There\n" +
                "was one on the house-front immediately opposite. BIG BROTHER IS WATCHING YOU,\n" +
                "the caption said, while the dark eyes looked deep into Winston's own.\n\n" +
                "Down at street level another poster, torn at one corner, flapped fitfully in\n" +
                "the wind, alternately covering and uncovering the single word INGSOC. In the\n" +
                "far distance a helicopter skimmed low over the rooftops, peering into the\n" +
                "windows.",

                // Page 4
                "PART ONE — III\n\n" +
                "Winston's diary.\n\n" +
                "April 4th, 1984.\n\n" +
                "Last night to the flicks. All war films. One very good one of a ship full of\n" +
                "refugees being bombed somewhere in the Mediterranean. Audience much amused by\n" +
                "shots of a great huge fat man trying to swim away with a helicopter after him,\n" +
                "first you saw him wallowing along in the water like a porpoise, then you saw\n" +
                "him through the helicopters gunsights, then he was full of holes and the sea\n" +
                "round him turned pink and he sank as suddenly as though the holes had let in\n" +
                "the water, audience shouting with laughter when he sank.\n\n" +
                "WAR IS PEACE.\nFREEDOM IS SLAVERY.\nIGNORANCE IS STRENGTH.",

                // Page 5
                "PART TWO — I\n\n" +
                "It was in the middle of the morning, and Winston had left the cubicle to go\n" +
                "to the lavatory.\n\n" +
                "A solitary figure was coming towards him from the other end of the long,\n" +
                "bright-lit corridor. It was the girl with dark hair. Four days had passed\n" +
                "since the evening in the Ministry canteen. As she came nearer he saw that\n" +
                "her right arm was in a sling, not noticeable at a distance because it was\n" +
                "the same colour as her overalls.\n\n" +
                "She must have fallen and hurt herself, he thought. His heart beat so\n" +
                "violently that he was sure she would see it. Then she fell. She fell flat\n" +
                "on her face and lay sprawled with her arm folded under her.",

                // Page 6
                "APPENDIX — The Principles of Newspeak\n\n" +
                "Newspeak was the official language of Oceania and had been devised to meet\n" +
                "the ideological needs of Ingsoc, or English Socialism. In the year 1984\n" +
                "there was not as yet anyone who used Newspeak as his sole means of\n" +
                "communication, either in speech or writing.\n\n" +
                "The purpose of Newspeak was not only to provide a medium of expression\n" +
                "for the world-view and mental habits proper to the devotees of Ingsoc,\n" +
                "but to make all other modes of thought impossible. It was intended that\n" +
                "when Newspeak had been adopted once and for all and Oldspeak forgotten,\n" +
                "a heretical thought — that is, a thought diverging from the principles of\n" +
                "Ingsoc — should be literally unthinkable, at least so far as thought is\n" +
                "dependent on words.",
            ]
        ),

        new(
            "great-gatsby.pdf",
            "The Great Gatsby",
            "F. Scott Fitzgerald",
            [
                // Page 1
                "CHAPTER I\n\n" +
                "In my younger and more vulnerable years my father gave me some advice that\n" +
                "I've been turning over in my mind ever since.\n\n" +
                "\"Whenever you feel like criticizing any one,\" he told me, \"just remember\n" +
                "that all the people in this world haven't had the advantages that you've had.\"\n\n" +
                "He didn't say any more, but we've always been unusually communicative in a\n" +
                "reserved way, and I understood that he meant a great deal more than that.\n" +
                "In consequence, I'm inclined to reserve all judgments, a habit that has opened\n" +
                "up many curious natures to me and also made me the victim of not a few veteran\n" +
                "bores. The abnormal mind is quick to detect and attach itself to this quality\n" +
                "when it appears in a normal person, and so it came about that in college I was\n" +
                "unjustly accused of being a politician, because I was privy to the secret\n" +
                "griefs of wild, unknown men.",

                // Page 2
                "And so with the sunshine and the great bursts of leaves growing on the trees,\n" +
                "just as things grow in fast movies, I had that familiar conviction that life\n" +
                "was beginning over again with the summer.\n\n" +
                "There was so much to read, for one thing, and so much fine health to be\n" +
                "pulled down out of the young breath-giving air. I bought a dozen volumes on\n" +
                "banking and credit and investment securities, and they stood on my shelf in\n" +
                "red and gold like new money from the mint, promising to unfold the shining\n" +
                "secrets that only Midas and Morgan and Maecenas knew.\n\n" +
                "And I had the high intention of reading many other books besides. I was\n" +
                "rather literary in college — one year I wrote a series of very solemn and\n" +
                "obvious editorials for the \"Yale News\" — and now I was going to bring back\n" +
                "all such things into my life and become again that most limited of all\n" +
                "specialists, the \"well-rounded man.\"",

                // Page 3
                "CHAPTER III\n\n" +
                "There was music from my neighbor's house through the summer nights. In his\n" +
                "blue gardens men and girls came and went like moths among the whisperings\n" +
                "and the champagne and the stars. At high tide in the afternoon I watched his\n" +
                "guests diving from the tower of his raft, or taking the sun on the hot sand\n" +
                "of his beach while his two motor-boats slit the waters of the Sound, drawing\n" +
                "aquaplanes over cataracts of foam.\n\n" +
                "On week-ends his Rolls-Royce became an omnibus, bearing parties to and from\n" +
                "the city between nine in the morning and long past midnight, while his station\n" +
                "wagon scampered like a brisk yellow bug to meet all trains. And on Mondays\n" +
                "eight servants, including an extra gardener, toiled all day with mops and\n" +
                "scrubbing-brushes and hammers and garden-shears, repairing the ravages of\n" +
                "the night before.",

                // Page 4
                "CHAPTER VI\n\n" +
                "It was when curiosity about Gatsby was at its highest that the lights in his\n" +
                "house failed to go on one Saturday night — and, as obscurely as it had begun,\n" +
                "his career as Trimalchio was over. Only gradually did I become aware that\n" +
                "the automobiles which turned expectantly into his drive stayed for just a\n" +
                "minute and then drove sulkily away.\n\n" +
                "He had thrown himself into it with a creative passion, adding to it all the\n" +
                "time, decking it out with every bright feather that drifted his way. No\n" +
                "amount of fire or freshness can challenge what a man will store up in his\n" +
                "ghostly heart.\n\n" +
                "\"Can't repeat the past?\" he cried incredulously. \"Why of course you can!\"\n\n" +
                "He looked around him wildly, as if the past were lurking here in the shadow\n" +
                "of his house, just out of reach of his hand.",

                // Page 5
                "CHAPTER IX\n\n" +
                "After two years I remember the rest of that day, and that night and the next\n" +
                "day, only as an endless drill of police and photographers and newspaper men\n" +
                "in and out of Gatsby's front door. A rope stretched across the main gate\n" +
                "and a policeman by it kept out the curious, but little boys soon discovered\n" +
                "that they could enter through my yard, and there were always a few of them\n" +
                "clustered open-mouthed about the pool.\n\n" +
                "I tried to think about Gatsby then for a moment, but he was already too far\n" +
                "away, and I could only remember, without resentment, that Daisy hadn't sent\n" +
                "a message or a flower. Dimly I heard someone murmur \"Blessed are the dead\n" +
                "that the rain falls on,\" and then the owl-eyed man said \"Amen to that,\"\n" +
                "in a brave voice.",

                // Page 6
                "So we beat on, boats against the current, borne back ceaselessly into the past.\n\n" +
                "I see now that this has been a story of the West, after all — Tom and Gatsby,\n" +
                "Daisy and Jordan and I, were all Westerners, and perhaps we possessed some\n" +
                "deficiency in common which made us subtly unadaptable to Eastern life.\n\n" +
                "And as the moon rose higher the inessential houses began to melt away until\n" +
                "gradually I became aware of the old island here that flowered once for Dutch\n" +
                "sailors' eyes — a fresh, green breast of the new world. Its vanished trees,\n" +
                "the trees that had made way for Gatsby's house, had once pandered in whispers\n" +
                "to the last and greatest of all human dreams; for a transitory enchanted moment\n" +
                "man must have held his breath in the presence of this continent.",
            ]
        ),

        new(
            "pride-and-prejudice.pdf",
            "Pride and Prejudice",
            "Jane Austen",
            [
                // Page 1
                "CHAPTER I\n\n" +
                "It is a truth universally acknowledged, that a single man in possession of\n" +
                "a good fortune, must be in want of a wife.\n\n" +
                "However little known the feelings or views of such a man may be on his first\n" +
                "entering a neighbourhood, this truth is so well fixed in the minds of the\n" +
                "surrounding families, that he is considered as the rightful property of some\n" +
                "one or other of their daughters.\n\n" +
                "\"My dear Mr. Bennet,\" said his lady to him one day, \"have you heard that\n" +
                "Netherfield Park is let at last?\"\n\n" +
                "Mr. Bennet replied that he had not.\n\n" +
                "\"But it is,\" returned she; \"for Mrs. Long has just been here, and she told\n" +
                "me all about it.\"\n\n" +
                "Mr. Bennet made no answer.\n\n" +
                "\"Do not you want to know who has taken it?\" cried his wife impatiently.",

                // Page 2
                "\"You want to tell me, and I have no objection to hearing it.\"\n\n" +
                "This was invitation enough.\n\n" +
                "\"Why, my dear, you must know, Mrs. Long says that Netherfield is taken by\n" +
                "a young man of large fortune from the north of England; that he came down\n" +
                "on Monday in a chaise and four to see the place, and was so much delighted\n" +
                "with it, that he agreed with Mr. Morris immediately; that he is to take\n" +
                "possession before Michaelmas, and some of his servants are to be in the\n" +
                "house by the end of next week.\"\n\n" +
                "\"What is his name?\"\n\n" +
                "\"Bingley.\"\n\n" +
                "\"Is he married or single?\"\n\n" +
                "\"Oh! Single, my dear, to be sure! A single man of large fortune; four or\n" +
                "five thousand a year. What a fine thing for our girls!\"\n\n" +
                "\"How so? Can it affect them?\"\n\n" +
                "\"My dear Mr. Bennet,\" replied his wife, \"how can you be so tiresome!\"",

                // Page 3
                "CHAPTER III\n\n" +
                "Not all that Mrs. Bennet, however, with the assistance of her five daughters,\n" +
                "could ask on the subject was sufficient to draw from her husband any\n" +
                "satisfactory description of Mr. Bingley. They attacked him in various ways;\n" +
                "with barefaced questions, ingenious suppositions, and distant surmises; but\n" +
                "he eluded the skill of them all; and they were at last obliged to accept\n" +
                "the second-hand intelligence of their neighbour Lady Lucas.\n\n" +
                "The gentlemen pronounced him to be a fine figure of a man, the ladies\n" +
                "declared he was much handsomer than Mr. Bingley, and he was looked at with\n" +
                "great admiration for about half the evening, till his manners gave a disgust\n" +
                "which turned the tide of his popularity; for he was discovered to be proud,\n" +
                "to be above his company, and above being pleased.",

                // Page 4
                "CHAPTER XI\n\n" +
                "\"I have been used to consider poetry as the food of love,\" said Darcy.\n\n" +
                "\"Of a fine, stout, healthy love it may. Every thing nourishes what is strong\n" +
                "already. But if it be only a slight, thin sort of inclination, I am convinced\n" +
                "that one good sonnet will starve it entirely away.\"\n\n" +
                "Darcy only smiled; and the general pause which ensued made Elizabeth tremble\n" +
                "lest her mother should be exposing herself again. She longed to speak, but\n" +
                "could think of nothing to say; and after a short silence Mrs. Bennet began\n" +
                "repeating her thanks to Mr. Bingley for his kindness to Jane, with an\n" +
                "apology for troubling him also with Lizzy.",

                // Page 5
                "CHAPTER XXXIV — Mr. Darcy's Letter\n\n" +
                "Be not alarmed, Madam, on receiving this letter, by the apprehension of its\n" +
                "containing any repetition of those sentiments, or renewal of those offers,\n" +
                "which were last night so disgusting to you. I write without any intention\n" +
                "of paining you, or humbling myself, by dwelling on wishes, which, for the\n" +
                "happiness of both, cannot be too soon forgotten; and the effort which the\n" +
                "formation and the perusal of this letter must occasion, should have been\n" +
                "spared, had not my character required it to be written and read.\n\n" +
                "You must, therefore, pardon the freedom with which I demand your attention;\n" +
                "your feelings, I know, will bestow it unwillingly, but I demand it of your\n" +
                "justice.",

                // Page 6
                "CHAPTER LXI\n\n" +
                "Happy for all her maternal feelings was the day on which Mrs. Bennet got rid\n" +
                "of her two most deserving daughters. With what delighted pride she afterwards\n" +
                "visited Mrs. Bingley, and talked of Mrs. Darcy, may be guessed. I wish I\n" +
                "could say, for the sake of her family, that the accomplishment of her earnest\n" +
                "desire in the establishment of so many of her children, produced so happy an\n" +
                "effect as to make her a sensible, amiable, well-informed woman for the rest\n" +
                "of her life; though perhaps it was lucky for her husband, who might not have\n" +
                "relished domestic felicity in so unusual a form, that she still was occasionally\n" +
                "nervous and invariably silly.\n\n" +
                "Mr. Bennet missed his second daughter exceedingly; his affection for her drew\n" +
                "him oftener from home than any thing else could do.",
            ]
        ),

        new(
            "dune.pdf",
            "Dune",
            "Frank Herbert",
            [
                // Page 1
                "BOOK ONE — DUNE\n\n" +
                "A beginning is the time for taking the most delicate care that the balances\n" +
                "are correct. This every sister of the Bene Gesserit knows. To begin your\n" +
                "study of the life of Muad'Dib, then, take care that you first place him in\n" +
                "his time: born in the 57th year of the Padishah Emperor, Shaddam IV.\n\n" +
                "And take the most special care that you locate Muad'Dib in his place:\n" +
                "the planet Arrakis. Do not be deceived by the fact that he was born on\n" +
                "Caladan and lived his first fifteen years there. Arrakis, the planet known\n" +
                "as Dune, is forever his place.\n\n" +
                "— from \"Manual of Muad'Dib\" by the Princess Irulan",

                // Page 2
                "In the week before their departure to Arrakis, when all the final\n" +
                "scurrying about had reached a nearly unbearable frenzy, an old crone came\n" +
                "to visit the mother of the boy, Paul.\n\n" +
                "It was a warm night at Castle Caladan, and the ancient pile of stone that\n" +
                "had served the Atreides family as home for twenty-six generations bore that\n" +
                "cooled-sweat feeling it acquired before a change in the weather.\n\n" +
                "The old woman was let in by the side door down the vaulted passage by Paul's\n" +
                "room and she was allowed a moment to peer in at him where he lay in his bed.\n\n" +
                "She leaned close to Paul. Something about her dryness, about the birdlike\n" +
                "quickness of her movements, suggested a resemblance to a very old woman.",

                // Page 3
                "Paul sensed his mother behind him, heard the faint whisper of her robe.\n\n" +
                "\"Is he the one?\" the Reverend Mother asked.\n\n" +
                "\"We shall see,\" his mother said.\n\n" +
                "The Reverend Mother moved to the end of the bed and Paul heard a faint\n" +
                "clinking — metal touching metal. Then she was at his side, extending a\n" +
                "fist toward him with the back of the hand up.\n\n" +
                "\"Put your hand in the box,\" she said.\n\n" +
                "He looked at the box — black with no latch or hinge, its cover slightly open.\n" +
                "He sensed a deadliness in the thing.\n\n" +
                "\"What's in the box?\"\n\n" +
                "\"Pain.\"\n\n" +
                "His mother's voice came sharp: \"Paul!\"\n\n" +
                "He heard the fear in her voice and wondered at it. But he did as he was told.",

                // Page 4
                "I must not fear. Fear is the mind-killer. Fear is the little-death that\n" +
                "brings total obliteration. I will face my fear. I will permit it to pass\n" +
                "over me and through me. And when it has gone past I will turn the inner\n" +
                "eye to see its path. Where the fear has gone there will be nothing. Only\n" +
                "I will remain.\n\n" +
                "— Bene Gesserit Litany Against Fear\n\n" +
                "Paul kept his hand in the box. Cold began to move up his arm. He gritted\n" +
                "his teeth. The cold increased. He could feel the Reverend Mother's gaze\n" +
                "upon him — studying, weighing.\n\n" +
                "Presently, she spoke: \"You've heard of animals chewing off a leg to escape\n" +
                "a trap? There's an animal kind of trick. A human would remain in the trap,\n" +
                "endure the pain, feigning death that he might kill the trapper and remove\n" +
                "a threat to his kind.\"",

                // Page 5
                "BOOK TWO — MUAD'DIB\n\n" +
                "My father, the Padishah Emperor, was 72 years old when I was born, already\n" +
                "past the age that most men set down their work and take their ease. Even\n" +
                "had I not ascended to the throne, Paul would have inherited before he was\n" +
                "twenty. I have wondered since then what kind of ruler he might have made\n" +
                "had he been other than what he was — had he been, say, the son of someone\n" +
                "other than Jessica.\n\n" +
                "The Fremen are a desert people. A fierce, proud, and patient people. Their\n" +
                "eyes, stained a deep blue from the spice, held a quiet look — the look of\n" +
                "those accustomed to watching the horizon for something that may never come.\n\n" +
                "\"The spice must flow,\" Stilgar said. It was both a statement and a prayer.",

                // Page 6
                "BOOK THREE — THE PROPHET\n\n" +
                "The mystery of life isn't a problem to solve, but a reality to experience.\n\n" +
                "He was warrior and mystic, ogre and saint, the fox and the innocent, chivalrous,\n" +
                "ruthless, less than a god, more than a man. There is no measuring Muad'Dib's\n" +
                "motives by ordinary standards. In the moment of his triumph, he saw with\n" +
                "terrible clarity the extent of what he'd won — and what he'd lost.\n\n" +
                "The target of the Imperium's hatred and the idol of his people, he walked\n" +
                "a knife's-edge between total victory and total annihilation. He had seen\n" +
                "the future. He had seen his own death in a thousand futures. And in the\n" +
                "one future that he chose, all humanity paid the price.\n\n" +
                "\"God created Arrakis to train the faithful,\" the Fremen said. And it was true.",
            ]
        ),
    ];

    // ── PDF builder ───────────────────────────────────────────────────────────

    private record BookContent(
        string Filename,
        string Title,
        string Author,
        string[] Pages);

    private static byte[] BuildPdf(BookContent book)
    {
        // Object numbering layout:
        //   1 = Catalog, 2 = Pages, 3 = Font (Helvetica), 4 = Font (Helvetica-Bold)
        //   Then for each page i (0-based): pageObj = 5 + i*2, contentObj = 6 + i*2

        var pageCount = book.Pages.Length;
        var pageObjIds    = Enumerable.Range(0, pageCount).Select(i => 5 + i * 2).ToList();
        var contentObjIds = Enumerable.Range(0, pageCount).Select(i => 6 + i * 2).ToList();

        var objects = new SortedDictionary<int, string>();

        // Catalog
        objects[1] = "<< /Type /Catalog /Pages 2 0 R >>";

        // Pages node
        var kids = string.Join(" ", pageObjIds.Select(id => $"{id} 0 R"));
        objects[2] = $"<< /Type /Pages /Kids [{kids}] /Count {pageCount} >>";

        // Fonts
        objects[3] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>";
        objects[4] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>";

        // Pages + content streams
        for (int i = 0; i < pageCount; i++)
        {
            var pageId    = pageObjIds[i];
            var contentId = contentObjIds[i];

            objects[pageId] =
                $"<< /Type /Page /Parent 2 0 R " +
                $"/MediaBox [0 0 612 792] " +
                $"/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> " +
                $"/Contents {contentId} 0 R >>";

            var streamBody = BuildPageStream(
                book.Pages[i], i == 0 ? book.Title : null,
                i == 0 ? book.Author : null,
                i + 1, pageCount);

            objects[contentId] =
                $"<< /Length {Encoding.Latin1.GetByteCount(streamBody)} >>\n" +
                $"stream\n{streamBody}\nendstream";
        }

        return AssemblePdf(objects);
    }

    private static string BuildPageStream(
        string text, string? title, string? author,
        int pageNum, int totalPages)
    {
        var sb = new StringBuilder();
        const int leftMargin    = 72;
        const int topY          = 740;
        const int bodyFontSize  = 11;
        const int leading       = 16;
        const int titleFontSize = 16;
        const int charsPerLine  = 82;

        sb.Append("BT\n");

        int y = topY;

        if (title != null)
        {
            // Title
            sb.Append($"/F2 {titleFontSize} Tf\n");
            sb.Append($"{leftMargin} {y} Td\n");
            sb.Append($"({EscapePdf(title)}) Tj\n");
            y -= titleFontSize + 6;

            // Author
            sb.Append($"/F1 10 Tf\n");
            sb.Append($"{leftMargin} {y} Td\n");
            sb.Append($"({EscapePdf(author ?? "")}) Tj\n");
            y -= 10 + 20; // gap after author

            // Decorative rule (drawn as thin rectangle, done outside BT block)
        }

        // Body text
        sb.Append($"/F1 {bodyFontSize} Tf\n");
        sb.Append($"{leading} TL\n");

        // Split text into lines, wrapping long lines
        var rawLines = text.Split('\n');
        bool firstBodyLine = true;

        foreach (var rawLine in rawLines)
        {
            var wrapped = WrapLine(rawLine, charsPerLine);
            foreach (var line in wrapped)
            {
                if (firstBodyLine)
                {
                    sb.Append($"{leftMargin} {y} Td\n");
                    firstBodyLine = false;
                }
                else
                {
                    sb.Append("T*\n");
                }
                sb.Append($"({EscapePdf(line)}) Tj\n");
            }
        }

        sb.Append("ET\n");

        // Page number at bottom center
        sb.Append("BT\n");
        sb.Append("/F1 9 Tf\n");
        sb.Append($"270 40 Td\n");
        sb.Append($"({pageNum} / {totalPages}) Tj\n");
        sb.Append("ET\n");

        return sb.ToString();
    }

    private static string[] WrapLine(string line, int maxChars)
    {
        if (line.Length == 0) return [""]; // blank line preserved
        if (line.Length <= maxChars) return [line];

        var words = line.Split(' ');
        var lines = new List<string>();
        var current = new StringBuilder();

        foreach (var word in words)
        {
            if (current.Length > 0 && current.Length + 1 + word.Length > maxChars)
            {
                lines.Add(current.ToString());
                current.Clear();
            }
            if (current.Length > 0) current.Append(' ');
            current.Append(word);
        }
        if (current.Length > 0) lines.Add(current.ToString());
        return lines.ToArray();
    }

    private static string EscapePdf(string s)
    {
        // PDF string syntax: escape \ ( ) and non-Latin1 chars
        var sb = new StringBuilder(s.Length + 8);
        foreach (char c in s)
        {
            switch (c)
            {
                case '\\': sb.Append("\\\\"); break;
                case '(':  sb.Append("\\(");  break;
                case ')':  sb.Append("\\)");  break;
                case '\r': break; // skip
                default:
                    // Replace smart quotes / em-dashes with ASCII equivalents
                    sb.Append(c switch
                    {
                        '‘' or '’' => '\'',
                        '“' or '”' => '"',
                        '—' => '-',
                        '–' => '-',
                        '…' => "...",
                        _ => c > 127 ? '?' : (object)c
                    });
                    break;
            }
        }
        return sb.ToString();
    }

    private static byte[] AssemblePdf(SortedDictionary<int, string> objects)
    {
        var file = new StringBuilder();
        file.Append("%PDF-1.4\n");

        var offsets = new Dictionary<int, int>();

        foreach (var (num, body) in objects)
        {
            offsets[num] = file.Length;
            file.Append($"{num} 0 obj\n");
            file.Append(body);
            file.Append("\nendobj\n");
        }

        int xrefOffset = file.Length;
        int maxObj = objects.Keys.Max();

        file.Append("xref\n");
        file.Append($"0 {maxObj + 1}\n");
        file.Append("0000000000 65535 f \n"); // object 0 = free

        for (int i = 1; i <= maxObj; i++)
        {
            if (offsets.TryGetValue(i, out var off))
                file.Append($"{off:D10} 00000 n \n");
            else
                file.Append("0000000000 65535 f \n");
        }

        file.Append("trailer\n");
        file.Append($"<< /Size {maxObj + 1} /Root 1 0 R >>\n");
        file.Append("startxref\n");
        file.Append($"{xrefOffset}\n");
        file.Append("%%EOF");

        return Encoding.Latin1.GetBytes(file.ToString());
    }
}
