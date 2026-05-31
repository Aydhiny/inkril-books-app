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

        new(
            "alchemist.pdf",
            "The Alchemist",
            "Paulo Coelho",
            [
                // Page 1
                "PROLOGUE\n\n" +
                "The Alchemist picked up a book that someone in the caravan had brought.\n" +
                "Leafing through the pages, he found a story about Narcissus.\n\n" +
                "The alchemist knew the legend of Narcissus, a youth who knelt daily beside\n" +
                "a lake to contemplate his own beauty. He was so fascinated by himself that,\n" +
                "one morning, he fell into the lake and drowned. At the spot where he fell,\n" +
                "a flower was born, which was called the narcissus.\n\n" +
                "But this was not how the author of the book ended the story.\n\n" +
                "He said that when Narcissus died, the goddesses of the forest appeared and\n" +
                "found the lake, which had been fresh water, transformed into a lake of\n" +
                "salty tears.\n\n" +
                "\"Why do you weep?\" the goddesses asked.\n\n" +
                "\"I weep for Narcissus,\" the lake replied.",

                // Page 2
                "\"Ah, it is no surprise that you weep for Narcissus,\" they said, \"for though\n" +
                "we always pursued him in the forest, you alone could contemplate his beauty\n" +
                "close at hand.\"\n\n" +
                "\"But... was Narcissus beautiful?\" the lake asked.\n\n" +
                "\"Who better than you to know that?\" the goddesses said in wonder. \"After\n" +
                "all, it was by your banks that he knelt each day to contemplate himself!\"\n\n" +
                "The lake was silent for some time.\n" +
                "Finally it said:\n" +
                "\"I weep for Narcissus, but I never noticed that Narcissus was beautiful.\n" +
                "I weep because, each time he knelt beside my banks, I could see, in the\n" +
                "depths of his eyes, my own beauty reflected.\"\n\n" +
                "\"What a lovely story,\" the Alchemist thought.",

                // Page 3
                "PART ONE\n\n" +
                "The boy's name was Santiago. Dusk was falling as the boy arrived with his\n" +
                "herd at an abandoned church. The roof had fallen in long ago, and an enormous\n" +
                "sycamore had grown up where the sacristy had once been.\n\n" +
                "He decided to spend the night there. He saw to it that all the sheep entered\n" +
                "the ruined gate, and then laid some planks across it to prevent the flock\n" +
                "from wandering away during the night. There were no wolves in the region,\n" +
                "but once a sheep had strayed during the night, and the boy had had to spend\n" +
                "the entire next day searching for it.\n\n" +
                "He swept the floor with his jacket and lay down, using the book he had just\n" +
                "finished reading as a pillow. He told himself that he would have to start\n" +
                "reading thicker books: they lasted longer, and made more comfortable pillows.",

                // Page 4
                "He had noticed that, in the caravan, everyone spoke of the desert as though\n" +
                "it were an old friend. This is my desert, one of the camel drivers told him.\n" +
                "The desert is a capricious woman, and she drives men crazy. But I love her.\n\n" +
                "Santiago had never thought of the desert as a woman before. For him, it was\n" +
                "only a destination — the place where he would find his treasure.\n\n" +
                "\"What draws you to the desert?\" he asked the oldest camel driver.\n\n" +
                "\"I've made this trip many times,\" the old man answered. \"But the desert is\n" +
                "so huge, and the horizons so distant, that they make a person feel small,\n" +
                "and as if he should remain silent. And when you are silent in the desert,\n" +
                "you begin to hear all sorts of things that are otherwise impossible to hear.\"",

                // Page 5
                "PART TWO\n\n" +
                "The boy reached the top of a dune and looked out at the horizon. He saw that\n" +
                "the desert was enormous and the sky above it vaster still. He felt afraid.\n\n" +
                "Then the wind began to blow. The wind from the east, the Levant, that carried\n" +
                "the desert's dust and the dreams of men who had ventured there.\n\n" +
                "\"I must listen to what the desert is trying to tell me,\" Santiago thought.\n" +
                "\"The Soul of the World speaks through the desert.\"\n\n" +
                "He remembered the words of the old king: \"When you want something, all the\n" +
                "universe conspires in helping you to achieve it.\"\n\n" +
                "Santiago looked at the sky again, and felt something he had not felt for a\n" +
                "long time: hope.",

                // Page 6
                "THE LANGUAGE OF THE WORLD\n\n" +
                "\"What is the world's greatest lie?\" the boy asked.\n\n" +
                "\"It's this: that at a certain point in our lives, we lose control of what's\n" +
                "happening to us, and our lives become controlled by fate.\"\n\n" +
                "\"That's the world's greatest lie.\"\n\n" +
                "\"No matter what he does, every person on earth plays a central role in the\n" +
                "history of the world. And normally he doesn't know it.\"\n\n" +
                "The Alchemist turned to the boy. \"Your heart already knows all this,\" he\n" +
                "said. \"What the heart knows, it knows without words. It speaks the Language\n" +
                "of the World.\"\n\n" +
                "Santiago placed his hand on his heart.\n" +
                "\"Tell me what my heart says,\" he asked.\n\n" +
                "\"Your heart is afraid that it will have to suffer,\" the Alchemist told him.\n" +
                "\"The fear of suffering is worse than the suffering itself.\"",

                // Page 7
                "THE PERSONAL LEGEND\n\n" +
                "There is one great truth on this planet: whoever you are, or whatever it is\n" +
                "that you do, when you really want something, it's because that desire\n" +
                "originated in the soul of the universe.\n\n" +
                "\"It's what you have always wanted to accomplish. Everyone, when they are young,\n" +
                "knows what their Personal Legend is. At that point in their lives, everything\n" +
                "is clear and everything is possible. They are not afraid to dream, and to yearn\n" +
                "for everything they would like to see happen to them in their lives.\"\n\n" +
                "\"But as time passes, a mysterious force begins to convince them that it will\n" +
                "be impossible for them to realize their Personal Legend.\"\n\n" +
                "The wind began to blow again, carrying Santiago's thoughts with it.",

                // Page 8
                "THE SOUL OF THE WORLD\n\n" +
                "\"The secret of happiness is to see all the marvels of the world, and never\n" +
                "to forget the drops of oil on the spoon.\"\n\n" +
                "Santiago thought about it for a moment. He understood.\n\n" +
                "There is a force that wants you to realize your Personal Legend; it whets\n" +
                "your appetite with a taste of success.\n\n" +
                "\"I don't know why we have to listen to our hearts,\" the boy complained.\n\n" +
                "\"Because, wherever your heart is, that is where you'll find your treasure.\"\n\n" +
                "\"But my heart is agitated,\" the boy said. \"It has its dreams, it gets\n" +
                "emotional, and it's become passionate over a woman of the desert.\"\n\n" +
                "\"That's good. Your heart is alive. Keep listening to what it has to say.\"",

                // Page 9
                "THE TREASURE\n\n" +
                "Santiago dug and dug, his hands raw, until at last he felt something hard.\n" +
                "He pulled it out: a box, rusted and heavy with gold coins and precious stones.\n\n" +
                "He laughed aloud, the sound carried away by the wind across the dunes.\n" +
                "He had come so far — through Spain, through the markets of Tangier, across\n" +
                "the immensity of the desert — and the treasure had always been here,\n" +
                "beneath the sycamore tree in the ruined church where he had his first dream.\n\n" +
                "\"How simple, and yet how right,\" he said to himself. \"To travel the world\n" +
                "only to find what was already yours.\"\n\n" +
                "But as he gathered the coins, he understood the truth at last:\n" +
                "the journey itself was the treasure.",

                // Page 10
                "PAULO COELHO — A NOTE\n\n" +
                "The Alchemist was first published in Portuguese in 1988 by Rocco Publishers\n" +
                "in Brazil. The first edition printed only 900 copies.\n\n" +
                "His publisher decided not to reprint the book. Coelho refused to give up.\n" +
                "He found another publisher, and the rest is history.\n\n" +
                "The Alchemist has sold more than 65 million copies, been translated into\n" +
                "80 languages, and holds the Guinness World Record for most translated book\n" +
                "by a living author.\n\n" +
                "\"When you want something, all the universe conspires in helping you to\n" +
                "achieve it.\"\n\n" +
                "This is perhaps the most quoted line in all of Coelho's work — and the\n" +
                "line that changed the lives of millions of readers around the world.",
            ]
        ),

        new(
            "mockingbird.pdf",
            "To Kill a Mockingbird",
            "Harper Lee",
            [
                // Page 1
                "PART ONE — Chapter 1\n\n" +
                "When he was nearly thirteen, my brother Jem got his arm badly broken at the\n" +
                "elbow. When it healed, and Jem's fears of never being able to play football\n" +
                "were assuaged, he was seldom self-conscious about his injury. His left arm\n" +
                "was somewhat shorter than his right; when he stood or walked, the back of\n" +
                "his hand was at right angles to his body, his thumb parallel to his thigh.\n\n" +
                "He couldn't have cared less, so long as he could pass and punt.\n\n" +
                "When enough years had gone by to enable us to look back on them, we sometimes\n" +
                "discussed the events leading to his accident. I maintain that the Ewells\n" +
                "started it all, but Jem, who was four years my senior, said it started long\n" +
                "before that.",

                // Page 2
                "Maycomb was an old town, but it was a tired old town when I first knew it.\n" +
                "In rainy weather the streets turned to red slop; grass grew on the sidewalks,\n" +
                "the courthouse sagged in the square. Somehow, it was hotter then: a black\n" +
                "dog suffered on a summer's day; bony mules hitched to Hoover carts flicked\n" +
                "flies in the sweltering shade of the live oaks on the square.\n\n" +
                "Men's stiff collars wilted by nine in the morning. Ladies bathed before noon,\n" +
                "after their three-o'clock naps, and by nightfall were like soft teacakes with\n" +
                "frostings of sweat and sweet talcum.\n\n" +
                "People moved slowly then. They ambled across the square, shuffled in and\n" +
                "out of the stores around it, took their time about everything. A day was\n" +
                "twenty-four hours long but seemed longer.",

                // Page 3
                "CHAPTER 3 — Calpurnia\n\n" +
                "Calpurnia was something else again. She was all angles and bones; she was\n" +
                "nearsighted; she squinted; her hand was wide as a bed slat and twice as hard.\n" +
                "She was always ordering me out of the kitchen, asking me why I couldn't\n" +
                "behave as well as Jem when she knew he was older, and calling me home when I\n" +
                "wasn't ready to come.\n\n" +
                "Our battles were epic and one-sided. Calpurnia always won, mainly because\n" +
                "Atticus always took her side. She had been with us ever since Jem was born,\n" +
                "and I had felt her tyrannical presence as long as I could remember.\n\n" +
                "Our father said Calpurnia had more education than most colored folks.",

                // Page 4
                "PART TWO — Chapter 17\n\n" +
                "It was Atticus's turn. He sat quietly for a moment, then began:\n\n" +
                "\"Bob Ewell, would you please write your name for the jury?\" he asked.\n\n" +
                "Mayella's father hesitated a moment — long enough for the jury to see that\n" +
                "he had a momentary lapse of memory about which hand he wrote with. He reached\n" +
                "over and picked up the pen with his left hand.\n\n" +
                "\"He's left-handed,\" Miss Maudie whispered to me.\n\n" +
                "Jem was rigid. I touched his arm and felt the muscles tense under my fingers.\n" +
                "Atticus had sat down again, and I could see him leaning back in his chair\n" +
                "looking at nothing. He was done for the day.",

                // Page 5
                "CHAPTER 20 — Atticus's Closing\n\n" +
                "\"Gentlemen,\" he said. Jem and I again looked at each other: Atticus might\n" +
                "be talking to us.\n\n" +
                "\"I shall be brief, but I would like to use my remaining time with you to\n" +
                "remind you that this case is not a difficult one, it requires no minute\n" +
                "sifting of complicated facts, but it does require you to be sure beyond all\n" +
                "reasonable doubt as to the guilt of the defendant.\"\n\n" +
                "\"To begin with, this case should never have come to trial. This case is\n" +
                "as simple as black and white.\"\n\n" +
                "\"The state has not produced one iota of medical evidence to the effect\n" +
                "that the crime Tom Robinson is charged with ever took place.\"\n\n" +
                "\"Thomas Robinson now looks at you.\"\n\n" +
                "\"In the name of God, do your duty.\"\n\n" +
                "\"In the name of God, believe him.\"",

                // Page 6
                "CHAPTER 22 — The Verdict\n\n" +
                "It was Jem's turn to cry. His shoulders shook and his head dropped forward.\n\n" +
                "\"It ain't right,\" he muttered, all the way to the corner of the square where\n" +
                "we waited for Atticus. It wasn't right. The jury had been gone less than an\n" +
                "hour when it returned — a verdict most people could not have foreseen, and\n" +
                "which should not have been possible.\n\n" +
                "I looked around. They were standing. All around us and in the balcony on the\n" +
                "opposite wall, the Negroes were getting to their feet.\n\n" +
                "Reverend Sykes's voice was as distant as Judge Taylor's:\n" +
                "\"Miss Jean Louise, stand up. Your father's passin'.\"",

                // Page 7
                "CHAPTER 25 — Aftermath\n\n" +
                "Maycomb was interested by the news of Tom's death for perhaps two days;\n" +
                "two days was enough for the information to spread through the county.\n\n" +
                "\"Typical of a nigger to cut and run,\" said Mr. Stephanie Crawford.\n" +
                "\"Scared him to death.\" Tom's death was Maycomb's usual disease.\n\n" +
                "To Maycomb, Tom's death was typical. Typical of a nigger to cut and run,\n" +
                "typical of a nigger's mentality to have no plan, no thought for the future,\n" +
                "just run blind first chance he saw. Funny thing, Atticus Finch might've\n" +
                "got him off scot free, but wait — ? Hell no. You know how they are.\n" +
                "Easy come, easy go.\n\n" +
                "Sure, Atticus Finch might've got him off. Maybe you'll feel better when\n" +
                "you know that she wasn't — that Tom was a dead man the minute Mayella\n" +
                "Ewell opened her mouth.",

                // Page 8
                "CHAPTER 28 — Boo Radley\n\n" +
                "Jem was beginning to feel nervous. I could feel it. We were almost at the\n" +
                "tree when I stumbled on something. I went down hard on the ground.\n\n" +
                "I heard Jem scream, and then a scuffling sound. Then someone coughed nearby.\n\n" +
                "Jem hollered something, and then he was still. I waited.\n" +
                "\"Jem?\" Nothing.\n\n" +
                "There was a crunching sound, then someone pulled me upright. I thought it\n" +
                "was Jem, but it wasn't. It was someone I didn't know.\n\n" +
                "He was carrying Jem. He was going up the porch steps.\n\n" +
                "\"Hey, Boo,\" I said.\n\n" +
                "\"Will you take me home?\" he almost whispered.\n" +
                "\"Yes,\" I said, \"I will.\"\n\n" +
                "I took him by the hand, a hand surprisingly warm and smooth.",

                // Page 9
                "CHAPTER 31 — Atticus\n\n" +
                "Atticus was waiting at the door. I walked into his arms.\n\n" +
                "\"Atticus, he was real nice...\"\n\n" +
                "His hands were under my chin, pulling up the ruined costume, tearing it away.\n" +
                "In the faint light Atticus's face was grave.\n\n" +
                "\"Most people are, Scout, when you finally see them.\"\n\n" +
                "He turned out the light and went into Jem's room. He would be there all night,\n" +
                "and he would be there when Jem woke up in the morning.\n\n" +
                "I was very tired, and I fell asleep as soon as I lay down.\n\n" +
                "When I woke in the morning I felt a warmth beside me. Atticus had fallen\n" +
                "asleep reading — a book lay open across his chest, his glasses on his nose.",

                // Page 10
                "HARPER LEE — A NOTE\n\n" +
                "To Kill a Mockingbird was published on July 11, 1960. It won the Pulitzer\n" +
                "Prize for Fiction in 1961, only a year after its release.\n\n" +
                "Harper Lee had struggled to sell the manuscript. An editor at Lippincott\n" +
                "told her she would need to rewrite it almost completely, and she did —\n" +
                "spending the next two and a half years revising.\n\n" +
                "The novel has sold more than 45 million copies worldwide and remains one of\n" +
                "the most widely read books in the English language. It is taught in\n" +
                "virtually every American high school.\n\n" +
                "In 2006, British librarians ranked it ahead of the Bible as the book \"every\n" +
                "adult should read before they die.\"\n\n" +
                "\"You never really understand a person until you consider things from his\n" +
                "point of view... until you climb into his skin and walk around in it.\"\n" +
                "— Atticus Finch",
            ]
        ),

        new(
            "little-prince.pdf",
            "The Little Prince",
            "Antoine de Saint-Exupery",
            [
                // Page 1
                "CHAPTER I\n\n" +
                "Once when I was six years old I saw a magnificent picture in a book, called\n" +
                "True Stories from Nature, about the primeval forest. It was a picture of a\n" +
                "boa constrictor in the act of swallowing an animal. Here is a copy of the drawing.\n\n" +
                "In the book it said: \"Boa constrictors swallow their prey whole, without\n" +
                "chewing it. After that they are not able to move, and they sleep through the\n" +
                "six months that they need for digestion.\"\n\n" +
                "I pondered deeply, then, over the adventures of the jungle. And after some\n" +
                "work with a coloured pencil I succeeded in making my first drawing. My\n" +
                "Drawing Number One. It looked like this.\n\n" +
                "I showed my masterpiece to the grown-ups, and asked them whether the drawing\n" +
                "frightened them.\n" +
                "But they answered: \"Frighten? Why should any one be frightened by a hat?\"\n\n" +
                "My drawing was not a picture of a hat. It was a picture of a boa constrictor\n" +
                "digesting an elephant.",

                // Page 2
                "CHAPTER II\n\n" +
                "So I lived my life alone, without anyone that I could really talk to, until\n" +
                "I had an accident with my plane in the Desert of Sahara, six years ago.\n\n" +
                "Something was broken in my engine. And as I had with me neither a mechanic\n" +
                "nor any passengers, I set myself to attempt the difficult repairs all alone.\n" +
                "It was a question of life or death for me: I had scarcely enough drinking\n" +
                "water to last a week.\n\n" +
                "The first night, then, I went to sleep on the sand, a thousand miles from\n" +
                "any human habitation. I was more isolated than a shipwrecked sailor on a\n" +
                "raft in the middle of the ocean.\n\n" +
                "You can imagine my amazement, at sunrise, when I was awakened by an odd\n" +
                "little voice. It said:\n" +
                "\"If you please — draw me a sheep!\"",

                // Page 3
                "CHAPTER VII\n\n" +
                "\"I know a planet where there is a certain red-faced gentleman. He has never\n" +
                "smelled a flower. He has never looked at a star. He has never loved any one.\n" +
                "He has never done anything in his life but add up figures. And all day he\n" +
                "says over and over, just like you: 'I am busy with matters of consequence!'\n" +
                "And that makes him swell up with pride. But he is not a man — he is a mushroom!\"\n\n" +
                "\"A what?\"\n\n" +
                "\"A mushroom!\"\n\n" +
                "The little prince was now white with rage.\n\n" +
                "\"The flowers have been growing thorns for millions of years. For millions of\n" +
                "years the sheep have been eating them just the same. And is it not a matter\n" +
                "of consequence to try to understand why the flowers go to so much trouble to\n" +
                "grow thorns which are never of any use to them?\"",

                // Page 4
                "CHAPTER XIV — The Lamplighter\n\n" +
                "The fifth planet was very strange. It was the smallest of all. There was just\n" +
                "enough room on it for a street lamp and a lamplighter.\n\n" +
                "The little prince could not understand what good a street lamp and a lamplighter\n" +
                "could be on a planet with no people and no houses.\n\n" +
                "But he thought to himself: \"Perhaps this man is absurd. But he is less absurd\n" +
                "than the king, the conceited man, the businessman, and the tippler. For at\n" +
                "least his work has some meaning. When he lights his street lamp, it is as if\n" +
                "he brought one more star to life, or one flower.\"\n\n" +
                "\"That is a beautiful occupation. And since it is beautiful, it is truly useful.\"",

                // Page 5
                "CHAPTER XXI — The Fox\n\n" +
                "It was then that the fox appeared.\n\n" +
                "\"Good morning,\" said the fox.\n" +
                "\"Good morning,\" the little prince responded politely.\n\n" +
                "\"Who are you?\" asked the little prince. \"You are very pretty to look at.\"\n\n" +
                "\"I am a fox,\" said the fox.\n\n" +
                "\"Come and play with me,\" proposed the little prince. \"I am so unhappy.\"\n\n" +
                "\"I cannot play with you,\" the fox said. \"I am not tamed.\"\n\n" +
                "\"Ah! please excuse me,\" said the little prince. But, after some thought,\n" +
                "he added: \"What does that mean — 'tame'?\"\n\n" +
                "\"It means to establish ties,\" said the fox. \"To me, you are still nothing\n" +
                "more than a little boy who is just like a hundred thousand other little boys.\n" +
                "And I have no need of you. And you, on your part, have no need of me.\"",

                // Page 6
                "\"To you, I am nothing more than a fox like a hundred thousand other foxes.\n" +
                "But if you tame me, then we shall need each other. To me, you will be\n" +
                "unique in all the world. To you, I shall be unique in all the world.\"\n\n" +
                "\"My life is very monotonous,\" the fox said. \"I hunt chickens; men hunt me.\n" +
                "All the chickens are just alike, and all the men are just alike. And, in\n" +
                "consequence, I am a little bored.\"\n\n" +
                "\"But if you tame me, it will be as if the sun came to shine on my life.\n" +
                "I shall know the sound of a step that will be different from all the others.\n" +
                "Other steps send me hurrying back underneath the ground. Yours will call me,\n" +
                "like music, out of my burrow.\"\n\n" +
                "The little prince tamed the fox.\n" +
                "\"It is only with the heart that one can see rightly; what is essential is\n" +
                "invisible to the eye.\"",

                // Page 7
                "CHAPTER XXIV\n\n" +
                "\"What makes the desert beautiful,\" said the little prince, \"is that somewhere\n" +
                "it hides a well...\"\n\n" +
                "I was astonished by a sudden understanding of that mysterious radiation of\n" +
                "the sands. When I was a little boy I lived in an old house, and legend told\n" +
                "us that a treasure was buried there. To be sure, no one had ever known how\n" +
                "to find it; perhaps no one had ever even looked for it.\n\n" +
                "But it cast an enchantment over that house. My house was hiding a secret in\n" +
                "the depths of its heart...\n\n" +
                "\"Yes,\" I said to the little prince, \"whether it is the house, the stars, or\n" +
                "the desert — what gives them their beauty is something that is invisible!\"\n\n" +
                "\"I am glad,\" he said, \"that you agree with my fox.\"",

                // Page 8
                "CHAPTER XXVI — The Snake\n\n" +
                "\"You have good poison? You are sure that it will not make me suffer too long?\"\n\n" +
                "The snake appeared.\n" +
                "\"You have good poison? You are sure that it will not make me suffer too long?\"\n\n" +
                "I stopped breathing. But I said, one more time:\n" +
                "\"Now run along, and let me get down from the tree.\"\n\n" +
                "\"Tonight,\" said the little prince, \"don't come.\"\n" +
                "\"I shall not leave you.\"\n" +
                "\"I shall look as if I were suffering. I shall look a little as if I were\n" +
                "dying. It is like that. Do not come to see that. It is not worth the trouble.\"\n\n" +
                "\"I shall not leave you.\"\n\n" +
                "He sat down because he was afraid.\n" +
                "\"You know — my flower... I am responsible for her.\"\n\n" +
                "\"The stars are beautiful because of a flower that cannot be seen.\"",

                // Page 9
                "CHAPTER XXVII\n\n" +
                "And now six years have already gone by...\n\n" +
                "I have never yet told this story. The companions who met me on my return\n" +
                "were well content to see me alive. I was sad, but I told them: \"I am tired.\"\n\n" +
                "Now my sorrow is comforted a little. That is, not entirely. But I know that\n" +
                "he did go back to his planet, because I did not find his body at daybreak.\n" +
                "It was not such a heavy body... and at night I love to listen to the stars.\n" +
                "It is like five hundred million little bells...\n\n" +
                "But there is one extraordinary thing... when I drew the muzzle for the little\n" +
                "prince, I forgot to add the leather strap to it. He will never have been able\n" +
                "to fasten it on his sheep.\n\n" +
                "So now I keep wondering: what has happened on his planet?",

                // Page 10
                "ANTOINE DE SAINT-EXUPERY — A NOTE\n\n" +
                "The Little Prince was published in French and English simultaneously in the\n" +
                "United States in April 1943. Saint-Exupery died in July 1944 when the\n" +
                "reconnaissance plane he was flying disappeared over the Mediterranean.\n\n" +
                "It is the most-read and most-translated French-language literary work in\n" +
                "the world. It has been translated into more than 300 languages and dialects\n" +
                "and has sold more than 140 million copies.\n\n" +
                "\"Grown-ups never understand anything by themselves, and it is tiresome for\n" +
                "children to be always and forever explaining things to them.\"\n\n" +
                "\"All grown-ups were once children — although few of them remember it.\"\n\n" +
                "The book is dedicated: \"To Leon Werth — I ask the indulgence of the children\n" +
                "who may read this book for dedicating it to a grown-up. I have a serious\n" +
                "reason: he is the best friend I have in the world.\"",
            ]
        ),

        new(
            "1984.pdf",
            "1984",
            "George Orwell",
            [
                "PART ONE — Chapter 1\n\n" +
                "It was a bright cold day in April, and the clocks were striking thirteen.\n" +
                "Winston Smith, his chin nuzzled into his breast in an effort to escape the\n" +
                "vile wind, slipped quickly through the glass doors of Victory Mansions,\n" +
                "though not quickly enough to prevent a swirl of gritty dust from entering\n" +
                "along with him.\n\n" +
                "The hallway smelt of boiled cabbage and old rag mats. At one end of it a\n" +
                "coloured poster, too large for the hall, had been tacked to the wall. It\n" +
                "depicted simply an enormous face, more than a metre wide: the face of a\n" +
                "man of about forty-five, with a heavy black moustache and ruggedly handsome\n" +
                "features. Winston made for the stairs.",

                "Chapter 2\n\n" +
                "Winston was dreaming of his mother. He must, he thought, have been ten or\n" +
                "eleven years old when his mother had disappeared. She was a tall, statuesque,\n" +
                "rather silent woman with slow movements and magnificent fair hair. His father\n" +
                "he remembered more vaguely as dark and thin, dressed always in neat dark\n" +
                "clothes (Winston remembered especially the very thin soles of his father's\n" +
                "shoes) and wearing spectacles.\n\n" +
                "The two of them must evidently have been swallowed up in one of the first\n" +
                "great purges of the fifties.",

                "Chapter 3\n\n" +
                "Winston had woken up with his eyes full of tears. Julia rolled sleepily\n" +
                "against him, murmuring something that might have been \"what's the matter?\"\n\n" +
                "\"I dreamt —\" he began, and stopped short. It was too complex to be put\n" +
                "into words. There was the dream itself, and there was a memory connected\n" +
                "with it that had swum into his mind in the few seconds after waking.\n\n" +
                "He lay back with his eyes shut, still sodden in the atmosphere of the dream.\n" +
                "It was a vast, luminous dream in which his whole life seemed to stretch out\n" +
                "before him like a landscape on a summer evening after rain.",

                "APPENDIX — The Principles of Newspeak\n\n" +
                "Newspeak was the official language of Oceania and had been devised to meet\n" +
                "the ideological needs of Ingsoc, or English Socialism. In the year 1984 there\n" +
                "was not as yet anyone who used Newspeak as his sole means of communication,\n" +
                "either in speech or writing. The leading articles in the Times were written\n" +
                "in it, but this was a tour de force which could only be carried out by a\n" +
                "specialist. It was expected that Newspeak would have finally superseded\n" +
                "Oldspeak (or Standard English, as we should call it) by about the year 2050.",
            ]
        ),

        new(
            "atomic-habits.pdf",
            "Atomic Habits",
            "James Clear",
            [
                "INTRODUCTION\n\n" +
                "The Surprising Power of Tiny Habits\n\n" +
                "In 2010, the British Cycling team hired Dave Brailsford as its new performance\n" +
                "director. At the time, professional cycling in Great Britain was in a dismal\n" +
                "state. For 110 years, British cyclists had failed to win the Tour de France.\n" +
                "In fact, the performance of British riders had been so underwhelming that one\n" +
                "top bike manufacturer refused to sell bikes to the team for fear that it would\n" +
                "hurt sales if other professionals saw Brits riding their gear.\n\n" +
                "Brailsford had been hired to put a new strategy in place. His approach was\n" +
                "simple: the aggregation of marginal gains. \"The whole principle came from\n" +
                "the idea that if you broke down everything you could think of that goes into\n" +
                "riding a bike, and then improved it by 1 percent, you will get a significant\n" +
                "increase when you put them all together.\"",

                "CHAPTER 1 — The Surprising Power of Atomic Habits\n\n" +
                "It is so easy to overestimate the importance of one defining moment and\n" +
                "underestimate the value of making small improvements on a daily basis.\n" +
                "Too often, we convince ourselves that massive success requires massive action.\n\n" +
                "Whether it is losing weight, building a business, writing a book, winning a\n" +
                "championship, or achieving any other goal, we put pressure on ourselves to\n" +
                "make some earth-shattering improvement that everyone will talk about.\n\n" +
                "Meanwhile, improving by 1 percent isn't particularly notable — sometimes it\n" +
                "isn't even noticeable — but it can be far more meaningful, especially in the\n" +
                "long run. The difference a tiny improvement can make over time is astounding.",

                "CHAPTER 2 — How Your Habits Shape Your Identity\n\n" +
                "There are three layers of behavior change. The first layer is changing your\n" +
                "outcomes. This level is concerned with changing your results: losing weight,\n" +
                "publishing a book, winning a championship. Most of the goals you set are\n" +
                "associated with this level of change.\n\n" +
                "The second layer is changing your process. This level is concerned with\n" +
                "changing your habits and systems: implementing a new routine at the gym,\n" +
                "decluttering your desk for better workflow, developing a meditation practice.\n\n" +
                "The third and deepest layer is changing your identity. This level is concerned\n" +
                "with changing your beliefs: your worldview, your self-image, your judgments\n" +
                "about yourself and others. Most of the beliefs, assumptions, and biases you\n" +
                "hold are associated with this level.",

                "CHAPTER 3 — How to Build Better Habits in 4 Simple Steps\n\n" +
                "In 1898, Edward Thorndike conducted an experiment that would lay the\n" +
                "foundation for our understanding of how habits form and the rules that guide\n" +
                "behavior. Thorndike was interested in studying the behavior of animals, and\n" +
                "he began by working with cats.\n\n" +
                "He would place each cat inside a device known as a puzzle box. The box was\n" +
                "designed so that the cat could escape through a door by pressing a lever.\n" +
                "Once the cat escaped, it received a food reward. Thorndike placed each cat\n" +
                "in the box, observed the behavior, and noted how long it took for the cat\n" +
                "to escape. He then repeated the process many times.",
            ]
        ),

        new(
            "sapiens.pdf",
            "Sapiens: A Brief History of Humankind",
            "Yuval Noah Harari",
            [
                "PART ONE — The Cognitive Revolution\n\n" +
                "About 13.5 billion years ago, matter, energy, time and space came into being\n" +
                "in what is known as the Big Bang. The story of these fundamental features of\n" +
                "our universe is called physics.\n\n" +
                "About 300,000 years after their appearance, matter and energy started to\n" +
                "coalesce into complex structures, called atoms, which then combined into\n" +
                "molecules. The story of atoms, molecules and their interactions is called\n" +
                "chemistry.\n\n" +
                "About 3.8 billion years ago, on a planet called Earth, certain molecules\n" +
                "combined to form particularly large and intricate structures called organisms.\n" +
                "The story of organisms is called biology.",

                "Chapter 2 — The Tree of Knowledge\n\n" +
                "The most important thing to know about prehistoric humans is that they were\n" +
                "insignificant animals with no more impact on their environment than gorillas,\n" +
                "fireflies or jellyfish.\n\n" +
                "Biologists classify organisms into species. Animals are said to belong to the\n" +
                "same species if they tend to mate with each other, giving birth to fertile\n" +
                "offspring. Horses and donkeys have a recent common ancestor, and share many\n" +
                "physical traits. But they show little sexual interest in each other. They will\n" +
                "mate if induced to do so — but their offspring, known as mules, are sterile.\n" +
                "Mutations in donkey DNA can therefore never cross over to horses, or vice versa.",

                "Chapter 3 — A Day in the Life of Adam and Eve\n\n" +
                "To understand our nature, history and psychology, we must get inside the\n" +
                "heads of our hunter-gatherer ancestors. For nearly the entire history of our\n" +
                "species, Sapiens lived as foragers. The past 200 years, during which ever\n" +
                "increasing numbers of Sapiens have obtained their daily bread as urban\n" +
                "labourers and office workers, and the preceding 10,000 years, during which\n" +
                "most Sapiens lived as farmers and herders, are the blink of an eye compared\n" +
                "to the tens of thousands of years during which our ancestors hunted and\n" +
                "gathered.",

                "PART TWO — The Agricultural Revolution\n\n" +
                "For 2.5 million years, humans fed themselves by gathering plants and hunting\n" +
                "animals that lived and bred without their intervention. Homo erectus, Homo\n" +
                "ergaster and the Neanderthals picked berries, dug up edible roots, tracked\n" +
                "deer and chased wild boar — without planting a single wheat grain, without\n" +
                "fencing off a single pasture, without feeding a single chicken.\n\n" +
                "Then, beginning about 10,000 years ago, Sapiens began to devote almost all\n" +
                "their time and effort to manipulating the lives of a few animal and plant\n" +
                "species.",
            ]
        ),

        new(
            "psychology-of-money.pdf",
            "The Psychology of Money",
            "Morgan Housel",
            [
                "Introduction\n\n" +
                "I once spent time with a guy in his 20s who liked to go to Vegas. He told\n" +
                "me he liked gambling for the social experience and the cheap rooms. On one\n" +
                "trip he won \\$14,000 playing blackjack. He then moved the winnings into a\n" +
                "stock brokerage account. But he didn't invest it. He treated it like a bank\n" +
                "account, adding and withdrawing as needed over the next few years until it\n" +
                "was eventually depleted. He never considered that the \\$14,000 of stock\n" +
                "market money had different value than the \\$14,000 of gambling money.\n\n" +
                "This is a book about the strange ways people think about money. Money is\n" +
                "everywhere, it affects all of us, and confuses most of us.",

                "Chapter 1 — No One's Crazy\n\n" +
                "Your personal experiences with money make up maybe 0.00000001% of what's\n" +
                "happened in the world, but maybe 80% of how you think the world works.\n\n" +
                "People do some crazy things with money. But no one is crazy.\n\n" +
                "Here's the thing: People from different generations, raised by different\n" +
                "parents who earned different incomes and held different values, in different\n" +
                "parts of the world, born into different economies, experiencing different\n" +
                "job markets with different incentives and different degrees of luck, learn\n" +
                "very different lessons.",

                "Chapter 2 — Luck and Risk\n\n" +
                "Bill Gates went to one of the only high schools in the world that had a\n" +
                "computer. The story of how Lakeside got a computer is remarkable.\n\n" +
                "In 1968 the Lakeside School's Mothers' Club decided to use the proceeds from\n" +
                "its annual rummage sale to buy a computer terminal for students. As Gates\n" +
                "has noted, this was an extraordinary piece of luck. Most universities didn't\n" +
                "have computing clubs in 1968. And Lakeside was a high school. Yet there Gates\n" +
                "was, with nearly unlimited access to a machine that few adults anywhere in\n" +
                "the world had encountered.",

                "Chapter 3 — Never Enough\n\n" +
                "At a party given by a billionaire on Shelter Island, Kurt Vonnegut informs\n" +
                "his pal, Joseph Heller, that their host, a hedge fund manager, had made more\n" +
                "money in a single day than Heller had earned from his wildly popular novel\n" +
                "Catch-22 over its whole history.\n\n" +
                "Heller responds, \"Yes, but I have something he will never have... enough.\"\n\n" +
                "Enough. I was stunned by the wisdom in those words, and the rarity of\n" +
                "actually being satisfied and not always craving more.",
            ]
        ),

        new(
            "deep-work.pdf",
            "Deep Work",
            "Cal Newport",
            [
                "Introduction\n\n" +
                "In the foreword I'm about to share, Adam Grant — a Wharton professor I will\n" +
                "discuss in more detail later in this book — offers a story that captures\n" +
                "something important about the world we now inhabit.\n\n" +
                "\"I have a confession to make. There are days when I turn on Freedom, a\n" +
                "web-blocking application, and the first thing I do when it kicks in is Google\n" +
                "information that I already know. I'm not looking for new insights. I'm just\n" +
                "procrastinating. The distraction isn't interrupting my work. It's becoming\n" +
                "my work.\"\n\n" +
                "Deep Work: Professional activities performed in a state of distraction-free\n" +
                "concentration that push your cognitive capabilities to their limit.",

                "PART 1 — The Idea\n\n" +
                "Chapter 1: Deep Work Is Valuable\n\n" +
                "The economy is changing in two specific ways that reward depth. First, as\n" +
                "the automation wave continues, the workers who will thrive are those who can\n" +
                "use intelligent machines to get results that are beyond what those machines\n" +
                "can do on their own. Second, the spread of digital communication networks\n" +
                "means that talented people can now collaborate and sell their work globally.\n\n" +
                "The key question becomes: how do you join the ranks of those who can work\n" +
                "this way? The answer, I argue, requires focusing on two core abilities.",

                "Chapter 2: Deep Work Is Rare\n\n" +
                "Open offices remain trendy. Facebook, for example, recently built the world's\n" +
                "largest open office, accommodating nearly three thousand people. These spaces\n" +
                "are popular, in part, because they're cheap — packing more people into less\n" +
                "square footage. But they're also promoted on the theory that they encourage\n" +
                "collaboration and the type of serendipitous encounters that spark creativity.\n\n" +
                "As Winifred Gallagher summarizes in her 2009 book Rapt: \"Who you are, what\n" +
                "you think, feel, and do, what you love — is the sum of what you focus on.\"",

                "PART 2 — The Rules\n\n" +
                "Rule 1: Work Deeply\n\n" +
                "You have a finite amount of willpower that becomes depleted as you use it.\n" +
                "Your will, in other words, is not a manifestation of your character that you\n" +
                "can deploy without limit; it's instead like a muscle that tires. This is why\n" +
                "the value of routines and rituals is often underappreciated.\n\n" +
                "The key to developing a deep work habit is to move beyond good intentions\n" +
                "and add routines and rituals to your working life designed to minimize the\n" +
                "amount of your limited willpower necessary to transition into and maintain\n" +
                "a state of unbroken concentration.",
            ]
        ),

        new(
            "thinking-fast-and-slow.pdf",
            "Thinking, Fast and Slow",
            "Daniel Kahneman",
            [
                "Introduction\n\n" +
                "This book presents my current understanding of judgment and decision making,\n" +
                "which has been shaped by psychological research conducted over many decades.\n" +
                "I have been studying cognitive biases since the early 1970s, and the field\n" +
                "has grown enormously since Daniel Kahneman and Amos Tversky first identified\n" +
                "the heuristics and biases program.\n\n" +
                "The premise of this book is that it is easier to recognize other people's\n" +
                "mistakes than our own. We will look at some aspects of thinking that tend\n" +
                "to go wrong, and I hope to teach you how to be a better thinker.",

                "Chapter 1 — The Characters of the Story\n\n" +
                "To observe your mind in automatic mode, glance at the image below.\n" +
                "Your experience as you look at the woman's face seamlessly combines what\n" +
                "we normally call seeing and intuitive thinking.\n\n" +
                "I describe mental life by the metaphor of two agents, called System 1 and\n" +
                "System 2, which respectively produce fast and slow thinking.\n\n" +
                "System 1 operates automatically and quickly, with little or no effort and\n" +
                "no sense of voluntary control.\n\n" +
                "System 2 allocates attention to the effortful mental activities that demand\n" +
                "it, including complex computations. The operations of System 2 are often\n" +
                "associated with the subjective experience of agency, choice, and concentration.",

                "Chapter 2 — Attention and Effort\n\n" +
                "Adam Smith, the great economist, had the intuition that labor is not the\n" +
                "only resource people contribute to their work. Smith wrote about \"the\n" +
                "attention and application of mind\" required to develop expert skills.\n\n" +
                "A crucial feature of System 2 is that its operations are effortful, and the\n" +
                "scarce resource that governs the level of activation is called attention.\n" +
                "You can do several things at once, but only if they are easy and undemanding.\n" +
                "You are probably able to walk and hold a conversation at the same time, but\n" +
                "not if you are trying to calculate 23 x 78.",

                "Chapter 3 — The Lazy Controller\n\n" +
                "One of the main functions of System 2 is to monitor and control thoughts\n" +
                "and actions \"suggested\" by System 1, allowing some to be expressed directly\n" +
                "in behavior and suppressing or modifying others.\n\n" +
                "For an example, here is a simple puzzle. Do not try to solve it, just\n" +
                "listen to your intuition:\n\n" +
                "A bat and a ball cost \\$1.10.\n" +
                "The bat costs one dollar more than the ball.\n" +
                "How much does the ball cost?\n\n" +
                "A number came to your mind. The number, of course, is 10 cents. The\n" +
                "distinctive mark of this easy puzzle is that it evokes an answer that is\n" +
                "intuitive, appealing, and wrong.",
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
