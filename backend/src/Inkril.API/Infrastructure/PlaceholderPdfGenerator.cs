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

                // Page 7
                "CHAPTER 41 — Moby Dick\n\n" +
                "I, Ishmael, was one of that crew; my shouts had gone up with the rest; my oath\n" +
                "had been welded with theirs; and stronger I shouted, and more did I hammer and\n" +
                "clinch my oath, because of the dread in my soul.\n\n" +
                "Moby Dick had been seen, before he was finally attacked, by various ships, and\n" +
                "by different captains; and in each of their accounts of the whale, each captain\n" +
                "would bestow upon him a special attribute peculiar to that encounter.\n\n" +
                "He was a creature of uncommon magnitude and malignity, which, combining with\n" +
                "his unexampled intelligence, had, in many prolonged, repeated experiences,\n" +
                "made him more strangely hideous than the waves themselves — more hideous,\n" +
                "even, than the darkness of death.",

                // Page 8
                "CHAPTER 119 — The Candles\n\n" +
                "The appearance of the ship was as a mast that had just been struck by lightning\n" +
                "and burned down to its stump. Three of the mast-heads were tipped with a\n" +
                "pallid fire; and all three long lance-poles of the royal masts were corposant.\n\n" +
                "\"The white flame but lights the way to the White Whale!\" cried Ahab.\n\n" +
                "The corpusants did light it. Ahab bent his head forward over the sea, the\n" +
                "lightning playing round him, lighting every plank and seam of his face.\n\n" +
                "\"I own thy speechless, placeless power; said I not so? Nor was it wrung from\n" +
                "me; nor do I now drop these links. Thou canst blind; but I can then grope.\n" +
                "Thou canst consume; but I can then be ashes.\"",

                // Page 9
                "CHAPTER 135 — The Chase — Third Day\n\n" +
                "The morning of the third day dawned fair and fresh, and once more the solitary\n" +
                "night-man at the fore-mast-head was relieved by crowds of the daylight look-outs.\n\n" +
                "\"There she blows — there she blows! A hump like a snow-hill! It is Moby Dick!\"\n\n" +
                "Fired by the cry which seemed simultaneously taken up by the three look-outs,\n" +
                "the men on deck rushed to the rigging to behold the famous whale they had so\n" +
                "long been pursuing. Ahab had now gained his final perch, some feet above the\n" +
                "other look-outs, Tashtego standing just beneath him on the cap of the top-gallant-mast.\n\n" +
                "\"Aye, aye! and I'll chase him round Good Hope, and round the Horn, and round\n" +
                "the Norway Maelstrom, and round perdition's flames before I give him up!\"",

                // Page 10
                "EPILOGUE\n\n" +
                "\"And I only am escaped alone to tell thee\" — Job\n\n" +
                "The drama's done. Why then here does any one step forth? — Because one did\n" +
                "survive the wreck.\n\n" +
                "It so chanced, that after the Parsee's disappearance, I was he whom the Fates\n" +
                "ordained to take the place of Ahab's bowsman, when that bowsman assumed the\n" +
                "vacant post; the same, who, when on the last day the three men were tossed\n" +
                "from out the rocking boat, was dropped astern.\n\n" +
                "Buoyed up by that coffin, for almost one whole day and night, I floated on\n" +
                "a soft and dirge-like main. The unharming sharks, they glided by as if with\n" +
                "padlocks on their mouths; the savage sea-hawks sailed with sheathed beaks.\n\n" +
                "On the second day, a sail drew near, nearer, and picked me up at last.\n" +
                "It was the devious-cruising Rachel, that in her retracing search after her\n" +
                "missing children, only found another orphan.",
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

                // Page 7
                "PART TWO — VII\n\n" +
                "It had happened at last. The expected message had come. All his life, it\n" +
                "seemed to Winston, he had been waiting for this to happen.\n\n" +
                "He was walking down the long corridor at the Ministry, and he was almost at\n" +
                "the telescreen, and then a girl was coming towards him. She was the girl with\n" +
                "the dark hair. Four or five seconds they were abreast of each other.\n\n" +
                "She had slipped something into his hand. There was no doubt that she had\n" +
                "done it intentionally. It was a small roll of paper.\n\n" +
                "He flattened it out. On it was written, in a large unformed handwriting:\n\n" +
                "I LOVE YOU.",

                // Page 8
                "PART THREE — I\n\n" +
                "He did not know where he was. Presumably he was in the Ministry of Love,\n" +
                "but there was no way of making certain.\n\n" +
                "He was in a high-ceilinged windowless cell with walls of glittering white\n" +
                "porcelain. Concealed lamps flooded it with cold light, and there was a\n" +
                "low, steady humming sound which he supposed had something to do with the\n" +
                "air supply.\n\n" +
                "\"Room 101,\" said the officer.\n\n" +
                "The cage was nearer; it was closing in. Winston heard a succession of shrill\n" +
                "cries which appeared to be coming from outside. He pressed his hands over\n" +
                "his face, trying to feel the cheekbones. The cheekbones felt right.\n\n" +
                "\"Do it to Julia! Do it to Julia! Not me! Julia!\"",

                // Page 9
                "PART THREE — VI\n\n" +
                "He was in the Ministry of Love, with everything forgiven, his soul white as\n" +
                "snow. He was in the public dock, confessing everything, implicating everybody.\n\n" +
                "He had walked miles over pavements, and his varicose ulcer had swelled up\n" +
                "until he walked with difficulty.\n\n" +
                "A waiter came and took away the nearly-untouched glass and the chessboard.\n" +
                "Winston looked at the enormous face. Forty years it had taken him to learn\n" +
                "what kind of smile was hidden beneath the dark moustache.\n\n" +
                "O cruel, needless misunderstanding! O stubborn, self-willed exile from the\n" +
                "loving breast! Two gin-scented tears trickled down the sides of his nose.\n" +
                "But it was all right, everything was all right, the struggle was finished.\n" +
                "He had won the victory over himself. He loved Big Brother.",

                // Page 10
                "AUTHOR'S NOTE — George Orwell, 1948\n\n" +
                "This book was written between 1947 and 1948, during a period of illness.\n" +
                "The world it describes is not an exact portrait of any country, but a\n" +
                "warning: totalitarianism, of whichever kind, leads inevitably to this.\n\n" +
                "The proles, if only they could somehow become conscious of their own\n" +
                "strength, would have no need to conspire. They needed only to rise up and\n" +
                "shake themselves like a horse shaking off flies.\n\n" +
                "\"If you want a picture of the future, imagine a boot stamping on a human\n" +
                "face — forever.\"\n\n" +
                "But perhaps the future is not yet determined. Perhaps there is still time.\n" +
                "Perhaps there will always be time — as long as there are people who remember\n" +
                "that 2 + 2 = 4, and are willing to say so.",
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

                // Page 7
                "CHAPTER IV — The Party\n\n" +
                "On Sunday morning while church bells rang in the villages along shore,\n" +
                "the world and its mistress returned to Gatsby's house and twinkled hilariously\n" +
                "on his lawn.\n\n" +
                "\"He's a bootlegger,\" said the young ladies, moving somewhere between his\n" +
                "cocktails and his flowers. \"One time he killed a man who had found out that\n" +
                "he was nephew to Von Hindenburg and second cousin to the devil. Reach me a\n" +
                "rose, honey, and pour me a last drop into that there crystal glass.\"\n\n" +
                "Once I wrote down on the empty spaces of a time-table the names of those\n" +
                "who came to Gatsby's house that summer. It is an old time-table now,\n" +
                "disintegrating at its folds, and headed \"This schedule in effect July 5th, 1922.\"",

                // Page 8
                "CHAPTER V — Reunited\n\n" +
                "When I came home to West Egg that night I was afraid for a moment that my\n" +
                "house was on fire. Two o'clock and the whole corner of the peninsula was\n" +
                "blazing with light, which fell unreal on the shrubbery and made thin elongating\n" +
                "glints upon the roadside wires.\n\n" +
                "Gatsby's house was still empty when I left — the lights in the living room\n" +
                "still blazed, still the empty corner by the fireplace, still the glass and the\n" +
                "dying flowers. On the last night, with my trunk packed and my car sold to the\n" +
                "grocer, I went over and looked at that huge incoherent failure of a house once more.\n\n" +
                "The lawn and drive had been crowded with the faces of those who guessed at\n" +
                "his corruption — and he had stood on those steps, concealing his incorruptible dream.",

                // Page 9
                "CHAPTER VII — The Heat\n\n" +
                "It was when curiosity about Gatsby was at its highest that the lights in his\n" +
                "house failed to go on one Saturday night.\n\n" +
                "\"What's the matter?\" demanded Daisy impatiently.\n\n" +
                "\"I did love him once — but I loved you too.\"\n\n" +
                "Gatsby's eyes opened and closed. \"You loved me too?\" he repeated.\n\n" +
                "\"Even that's a lie,\" said Tom savagely. \"She didn't know you were alive.\n" +
                "Why — there are things between Daisy and me that you'll never know, things\n" +
                "that neither of us can ever forget.\"\n\n" +
                "The words seemed to bite physically into Gatsby.\n\n" +
                "\"I want to speak to Daisy alone,\" he insisted. \"She's all worked up —\"\n\n" +
                "\"Even alone I can't say I never loved Tom,\" she admitted in a pitiful voice.\n" +
                "\"It wouldn't be true.\"",

                // Page 10
                "FINAL NOTE — F. Scott Fitzgerald\n\n" +
                "Gatsby believed in the green light, the orgastic future that year by year\n" +
                "recedes before us. It eluded us then, but that's no matter — tomorrow we\n" +
                "will run faster, stretch out our arms farther.\n\n" +
                "And one fine morning —\n\n" +
                "So we beat on, boats against the current.\n\n" +
                "The Great Gatsby was published on April 10, 1925, to mixed reviews.\n" +
                "Fitzgerald was disappointed by its reception. He died in 1940, never knowing\n" +
                "that his novel would become one of the greatest works of American literature.\n\n" +
                "Today it sells over half a million copies each year.\n\n" +
                "\"So we beat on, boats against the current, borne back ceaselessly into the past.\"\n" +
                "This closing line is arguably the most famous sentence in American fiction.",
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

                // Page 7
                "CHAPTER XVIII — The Ball at Netherfield\n\n" +
                "Till Elizabeth entered the drawing-room at Netherfield, and looked in vain for\n" +
                "Mr. Wickham among the cluster of red coats there assembled, a doubt of his\n" +
                "being present had never occurred to her.\n\n" +
                "She had dressed with more than usual care, and prepared in the highest spirits\n" +
                "for the conquest of all that remained unsubdued of his heart, trusting that it\n" +
                "was not more than might be won in the course of the evening.\n\n" +
                "But in an instant arose the dreadful suspicion of his being purposely omitted\n" +
                "for Mr. Darcy's pleasure in the Bingleys' invitation to the officers. This was\n" +
                "not exactly a charitable surmise, and once made, it was indulged without scruple.\n\n" +
                "\"I remember hearing you once say, Mr. Darcy, that you hardly ever forgave,\n" +
                "that your resentment once created was unappeasable. You are very cautious,\n" +
                "I suppose, as to its being created.\"",

                // Page 8
                "CHAPTER XXXVI — The Letter's Effect\n\n" +
                "If Elizabeth, when Mr. Darcy gave her the letter, did not expect it to contain\n" +
                "a renewal of his offers, she had formed no expectation at all of its contents.\n\n" +
                "But such as they were, it may well be supposed how eagerly she went through\n" +
                "them, and what a contrariety of emotion they excited.\n\n" +
                "She read with an eagerness which hardly left her power of comprehension, and\n" +
                "from impatience of knowing what the next sentence might bring, was incapable\n" +
                "of attending to the sense of the one before her eyes.\n\n" +
                "\"How despicably have I acted!\" she cried. \"I, who have prided myself on my\n" +
                "discernment! I, who have valued myself on my abilities! who have often disdained\n" +
                "the generous candour of my sister, and gratified my vanity, in useless or\n" +
                "blameable distrust. How humiliating is this discovery!\"",

                // Page 9
                "CHAPTER XLIII — Pemberley\n\n" +
                "Elizabeth, as they drove along, watched for the first appearance of Pemberley\n" +
                "Woods with some perturbation; and when at length they turned in at the lodge,\n" +
                "her spirits were in a high flutter.\n\n" +
                "The park was very large, and contained great variety of ground. They entered\n" +
                "it in one of its lowest points, and drove for some time through a beautiful\n" +
                "wood stretching over a wide extent.\n\n" +
                "Elizabeth's mind was too full for conversation, but she saw and admired every\n" +
                "remarkable spot and point of view. They gradually ascended for half-a-mile,\n" +
                "and then found themselves at the top of a considerable eminence, where the\n" +
                "wood ceased, and the eye was instantly caught by Pemberley House.\n\n" +
                "It was a large, handsome stone building, standing well on rising ground,\n" +
                "and backed by a ridge of high woody hills; and in front, a stream of some\n" +
                "natural importance was swelled into greater, but without any artificial\n" +
                "appearance. Its banks were neither formal nor falsely adorned.",

                // Page 10
                "JANE AUSTEN — A NOTE\n\n" +
                "Pride and Prejudice was first published on 28 January 1813. The novel had\n" +
                "been written between October 1796 and August 1797, and was originally titled\n" +
                "First Impressions.\n\n" +
                "Austen revised it substantially before publication. The opening sentence —\n" +
                "\"It is a truth universally acknowledged, that a single man in possession of\n" +
                "a good fortune, must be in want of a wife\" — has become one of the most\n" +
                "celebrated first lines in the English language.\n\n" +
                "The novel has been adapted into numerous films, television series, and stage\n" +
                "productions. It remains one of the best-selling novels of all time, with\n" +
                "over 20 million copies sold.\n\n" +
                "\"I declare after all there is no enjoyment like reading! How much sooner\n" +
                "one tires of any thing than of a book!\" — Miss Bingley, Chapter XI",
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

                // Page 7
                "THE FREMEN PROVERBS\n\n" +
                "The first step in avoiding a trap is knowing it exists.\n\n" +
                "Respect for the truth comes close to God. Arrakis teaches the attitude\n" +
                "of the knife — chopping off what's incomplete and saying: \"Now it's complete\n" +
                "because it's ended here.\"\n\n" +
                "He who controls the spice controls the universe.\n\n" +
                "The mystery of life isn't a problem to solve, but a reality to experience.\n\n" +
                "A process cannot be understood by stopping it. Understanding must move with\n" +
                "the flow of the process, must join it and flow with it.\n\n" +
                "\"My father once told me that respect for the truth comes close to God. Lying\n" +
                "is the only profanity — the only sin that cannot be forgiven.\"\n\n" +
                "You cannot go back. The arrow does not return to the bow.",

                // Page 8
                "THE SANDWORMS OF ARRAKIS\n\n" +
                "Deep in the desert, where no man dared walk, the Makers moved. The sandworms\n" +
                "of Arrakis — Shai-Hulud, the Old Man of the Desert, the Grandfather of the\n" +
                "Desert, Shaitan of the desert — these were the makers of spice.\n\n" +
                "Paul had seen it in visions: the worms as giant sandtrout in another age,\n" +
                "before the desert came. He had seen the ecological niche they filled,\n" +
                "the way they moved through sand as easily as a man through air.\n\n" +
                "To ride a worm was to claim Arrakis itself.\n\n" +
                "Stilgar extended his arm and Paul saw the ring of hooks on his palm.\n" +
                "\"You must place them precisely,\" Stilgar said, \"or the worm will turn on you.\"",

                // Page 9
                "CHANI'S LAMENT\n\n" +
                "I am Chani, daughter of Liet-Kynes. I am a Fremen. I have no home but\n" +
                "the desert. I have no water but the moisture of my own tears.\n\n" +
                "\"The land is our skin,\" my father said. \"To harm the land is to harm ourselves.\"\n\n" +
                "Paul came to us from off-world, as the prophecy said. The Lisan al-Gaib.\n" +
                "But prophecies are tools of control, my father warned. The Bene Gesserit\n" +
                "had seeded those words among us generations ago to serve their own purposes.\n\n" +
                "And yet — I watched him ride the worm. I watched him call the rain.\n" +
                "I watched him do what only a Fremen could do, and I loved him against my will.\n\n" +
                "Power was always his weakness. And it became mine.",

                // Page 10
                "FRANK HERBERT — A NOTE ON DUNE\n\n" +
                "Dune was first published in 1965 by Chilton Books. It had been rejected by\n" +
                "more than twenty publishers before finding its home.\n\n" +
                "Herbert conceived of the novel as an ecological parable. The spice, melange,\n" +
                "was his metaphor for oil: a finite resource controlled by an empire,\n" +
                "worth dying for, worth killing for.\n\n" +
                "The novel won the Hugo Award and the inaugural Nebula Award for Best Novel.\n" +
                "It remains the best-selling science fiction novel of all time.\n\n" +
                "\"I am not saying that I wrote the Dune series as an ecological handbook,\n" +
                "although ecology is certainly one of the novel's major themes.\"\n\n" +
                "\"The bottom line of the Dune trilogy is: beware of heroes. Much better to\n" +
                "rely on your own judgment, and your own mistakes.\" — Frank Herbert",
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
