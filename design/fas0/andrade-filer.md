# Artefaktmanifest

**GENERERAD FIL — kör `node tools/gen-manifest.mjs`, redigera inte för hand.** Byggs ALLRA SIST i kedjan, efter varje generator, och kontrolleras av `fas0/check-manifest.mjs` (CHK-MF-01) med samma enumerator som skrev den: `tools/manifest-contract.mjs`.

## Två lägen

| Läge | Yta | Krav | Set-likhet mot |
|---|---|---|---|
| `repo` | fristående checkout | `zip:/`-posterna får saknas | reporotsytan |
| `delivery` | uppackad ZIP | **varje `zip:/`-post krävs · set-likhet över HELA ytan** | reporotsytan **plus** alla `zip:/`-poster |
| `auto` | markören `zip:/fas0/DELIVERY` avgör | delivery när markören finns | följer valt läge |

**VALIDERAD LEVERANSROT.** Delivery-läget kräver att roten ligger exakt tre nivåer över reporoten, inte är filsystemets rot, och bär `zip:/fas0/DELIVERY` — annars exit 2. Traverseringen är djupbegränsad.

## Hela ytan, ingen allowlist (F1-H09)

Varje **vanlig fil** räknas, oavsett filändelse och katalog. Det finns ingen filtypslista och inga katalogundantag — `assets/`, `exports/` och lockup-katalogen räknades tidigare inte alls. Bara följande **exakta** sökvägar undantas, och de är körartefakter som skrivs av kedjan:

- `fas0/verify.log`
- `fas0/manifest.log`
- `fas0/verify-report.json`
- `fas0/kontrollstatus.md`
- `fas0/ci-evidence.json`
- `fas0/verify-exit`
- `fas0/verify-chain-exit`

Därtill `fas0/andrade-filer.md`, som inte kan bära sin egen hash.

**Avvisas, göms inte:** symlänkar (prövade med `lstatSync()` FÖRE varje annan kontroll), poster utanför rotens `realpath`, samt bygg-, dependency- och VCS-kataloger (`node_modules`, `dist`, `build`, `.svn`, `.hg`, `__pycache__`, `.venv`, `.cache` och `.git` i en leverans). Var och en fäller kontrollen med egen diagnostik.

<!--manifest:files=346-->

## Reporoten

| Fil | SHA-256 |
|---|---|
| `.github/workflows/verify.yml` | `769074037ab42d6b1c074d57e5be02152b14d353e1f512ea2fe3cd2d2945a87b` |
| `.thumbnail` | `c46e64bfadb3139f1a1f25f416ffb3492b4f206bd7cca938c3efc82563e83017` |
| `00-spec-index.md` | `d762b1261a80fb225bc2a61c902e090cf6a0ed0028206602a158cab70dc17941` |
| `Butlery Grafisk manual v6.dc.html` | `3879f2b3451f47de109db76b05f4fd18361f7c1318bebc625c1bdeca6fbd2964` |
| `Butlery Komponentark v1.dc.html` | `78f27a546502c7d2a9cb99aa954d6cd8ba3b5d18f1694aac2d9db1496ff1ed47` |
| `Butlery Skarmar v12 del 1 recept och veckomeny.dc.html` | `ca3a5e3b5bcf1cd0bf8e1823ac42a19c99318df68fed6bcf6655f57b24dfea4f` |
| `Butlery Skarmar v12 del 2 familj och socialt.dc.html` | `672c9d2842fb038e2c474115ab9babff46c09df7bb068838f19bceb5acd66f69` |
| `Butlery Skarmar v12 del 3 sok och skalbevis.dc.html` | `665c83da7a05cbf135ef22d6ae3037053d6183a02e8e9111c2fa43cfcb84c1f3` |
| `Butlery Skarmar v12 del 4 morkt lage och etapp 0-1.dc.html` | `733527919d0c6ab84b6a7acd22652006203aa5e58097be1209a828c9838a613b` |
| `Butlery Skarmar v12 etapp 10 bred layout.dc.html` | `6e2c0a0d1ff2edf84d132c0b411029284c55da85d1ca2fd45bc16c047200af1c` |
| `Butlery Skarmar v12 etapp 11 breda vyer.dc.html` | `330c9520138269fd3072b8e1088aba574343e0381162d7cde4520c4d8ceaf49c` |
| `Butlery Skarmar v12 etapp 2 inkop och skafferi.dc.html` | `a3ab5be9018777e88e9402fbac57e7b2d6ce68dd6b57dc3515e873809ac2d325` |
| `Butlery Skarmar v12 etapp 2.dc.html` | `19443f56eb9ba7e208c038eff01f89e77c9728c57af0e6c0c120cf0a62fdc469` |
| `Butlery Skarmar v12 etapp 3 onboarding.dc.html` | `7c7dd2bcc1317cba0af35450d81bcebcbc8b62ecf1531a4b2809d0bf8dd87179` |
| `Butlery Skarmar v12 etapp 4 import.dc.html` | `2720d8c0063048eae5bf2a2c0b54acfb73161a939d6f865dbcf654cc84531e7c` |
| `Butlery Skarmar v12 etapp 5-7.dc.html` | `f71d2f8588b961ed5d643af1b34773b26a49416f0b1dee64540421646614fff6` |
| `Butlery Skarmar v12 etapp 6 konto och integritet.dc.html` | `a00a0d4c5224354150d780d53e2f25653fe32fd469d560d0f2384cf4f6bd0ba7` |
| `Butlery Skarmar v12 etapp 9 globala tillstand och flerval.dc.html` | `10efeb2e1b7326ded563c037b6985b108a7dd0931f6bf0933072a91a5602753f` |
| `Butlery Skarmar v12 etapp 9 socialt och komponenter.dc.html` | `5abd118cfdd344851a56abcede11e19aea03a5793ade6b0daed7fa408ef29aa8` |
| `Butlery Skarmar v12.dc.html` | `c1b435cf7c470ebe31db64b82b5fc4ee94993391801130edee761f1540c893b2` |
| `Butlery beslut grund v13.dc.html` | `ce0aaa76a62fb6616d58e93fdaabd1c5b185bdf87ac11bfb60a91b3f7b324eaf` |
| `Butlery beslut kalendermatt v1.dc.html` | `8fb980fb2eb6c9805c14e8d1bc15421e3e57e5656df1d1ea735314b200f1cdb0` |
| `Butlery blockerande tickets.dc.html` | `dc8d379aaa1469f94d5189923972e6a498d5f5441e347e226dbef7eb19215e39` |
| `Butlery ceremonier rorelsereferens.dc.html` | `19cc633fbbfb4f1526430099e077557e8a6b0281e10fa2b1b02f51dc8a3aff9b` |
| `Butlery tillganglighetshandoff.dc.html` | `c9e27ba04adc39f6342a40bbe2adef394ac424f09201780e183b3f068f92c1a9` |
| `Butlery utestaende beslut.dc.html` | `a42589af8458f36e700689d3daf8fb5be688ae04e607c5ed1e44743d8863e536` |
| `Butlery-app-icon-gradde-platta-R4-6.svg` | `5003745e69f7fb491a5dd5487f1f4a2e98a803d691efc9e826d05d8e1a3d78cf` |
| `Butlery-app-icon-monoline-R4-6.svg` | `09b3a6e2548ee1b906b81f2c5a22bb5f304fa09158dac1a6fc7544c1cb6dd377` |
| `Butlery-app-icon-negativ-R4-6.svg` | `4e4a7e673550dbd3c2c55d9c2757099d60d9c34101822d84d5cfc63995f82ffd` |
| `Butlery-app-icon-solid-R4-6.svg` | `f5e6739bfdf1fb110f630097a5733844d3bd2be23d3e19798f3e66f105e050d9` |
| `Butlery-lockup-family-L4-3/Butlery-logo-horizontal-centred-light-L4-3-outlined.svg` | `d9b104c2dfff040e4e4087a7c4e8b2690be2bc39dc1dacf75763e0bd4de6a041` |
| `Butlery-lockup-family-L4-3/Butlery-logo-horizontal-centred-reversed-L4-3-outlined.svg` | `cc0f3ec358ff15ebe01584b74b40c97054c88b7242fc02e7665b51142a4f25f6` |
| `Butlery-lockup-family-L4-3/Butlery-logo-horizontal-centred-reversed-transparent-L4-3-outlined.svg` | `76059538af72a05151e241caf80c4197207ef1f486f35a933e14f06b15ac3e6d` |
| `Butlery-lockup-family-L4-3/Butlery-logo-monoline-light-L4-3-outlined.svg` | `29a566475250a5e0ae2b337240219c0f6d73915959b58c7741afe550f5d28cb8` |
| `Butlery-lockup-family-L4-3/Butlery-logo-monoline-reversed-L4-3-outlined.svg` | `be58af273c3581228b760f579d5f066c411363facdf06cc8f8616e5974c036b5` |
| `Butlery-lockup-family-L4-3/Butlery-logo-stacked-tight-light-L4-3-outlined.svg` | `348a46c4f1bdded79aaa5bf76d81081cc28892c8f0136dd9048a7463d1203b13` |
| `Butlery-lockup-family-L4-3/Butlery-logo-stacked-tight-reversed-L4-3-outlined.svg` | `5f07a457af7a9ffeab4f6d3a3d02ebb6ce92413fb7de70e8b5057f904397459f` |
| `Butlery-lockup-family-L4-3/Butlery-logo-stacked-tight-reversed-transparent-L4-3-outlined.svg` | `2c91d8d75c8acacf0c60601891169c168f3aed9fd0fbbb89e502dd8cf3e234c1` |
| `Butlery-lockup-family-L4-3/Butlery-mark-micro-light-L4-3.svg` | `c63d56b4bd9a35effc1dc7aeed8e263bbff2b814b946f6ee98772b282df8f8b2` |
| `Butlery-lockup-family-L4-3/Butlery-mark-micro-reversed-L4-3.svg` | `ad833989b42eab78b823087e662c9451ac9f6665408a9810a32b3cbce7e76d09` |
| `Butlery-lockup-family-L4-3/Butlery-wordmark-light-L4-3-outlined.svg` | `bc107250280d4aa21d69e5d9269bce78b18a4e81b1282d12827fc2e808087746` |
| `Butlery-lockup-family-L4-3/Butlery-wordmark-reversed-L4-3-outlined.svg` | `f490e61aa99d9be40b17682446167037ba153f21e0049fd164e2ab9bb91edb6b` |
| `FONT-VERSION.txt` | `b9b7731a213a7f4ae7d36bb8a5bdbb9ebd91c4dd093b8d08443d3a397e92cbcf` |
| `LAS-MIG-GRANSKNING.md` | `5305b92b1b958396e51e5985128f6f2b43f90415d8afa9445aa3548cb1fe8bdd` |
| `animations-v2.jsx` | `33e9200b93f5eb416d294e1a1ffc6bebe75d2bee95817977a08fa896229be774` |
| `arbetsplan.md` | `326221917cb77f0db4595c909d09d8ffe762ee11a5ee43f710d78c95cabfa81a` |
| `artifacts.json` | `dc2f16357181fc8a66f4b7917150620bfe08c831fd57762441d2694658dd9764` |
| `artifacts.schema.json` | `2cafc43ab6a147642447b21c4eb45aac9d38176f659021897ae67f13f86ebc57` |
| `assets-manifest.json` | `df7201da509c2359b5c35114a32a55755aa4647108cfb5824c1ae594144e64ec` |
| `assets/LICENSES.md` | `17d5f6fbdf80c3ccee9e420a646c3ebb03ec7a188eacb7a42eaae857ac942b95` |
| `assets/brand-colors.json` | `1cc1e0243b46309c56a2c2686c6401bfa200f1cc70fafcbc68dc99f973102935` |
| `assets/brand-colors.schema.json` | `7c16a20daa7be3856cbf48706940eeb065a44849cf8d6afd11fa4d9bfeeaf0af` |
| `assets/fonts/ButlerySans-0.626-Bold.ttf` | `ea2f924134a732405fa7d28afe64a899ef79f8ba5da8b18630f3f6d166477042` |
| `assets/fonts/ButlerySans-0.626-Bold.woff2` | `7295ac71e238c47d2238dabbb0f3df49eabe87d56333b1e144190aad3fbce923` |
| `assets/fonts/ButlerySans-0.626-BoldItalic.ttf` | `d01decb05f071f87929d6f3cc39a67524079309fe7ba7358976b95421fd5519d` |
| `assets/fonts/ButlerySans-0.626-BoldItalic.woff2` | `6d444a74361d4b0456fa6938bc087cf620e35cb296febb6d68f1031b95076c5e` |
| `assets/fonts/ButlerySans-0.626-Italic.ttf` | `a1541fed0877543028365157e0aaa5bb3187ca5fadc0ff11171e17b959feaf6a` |
| `assets/fonts/ButlerySans-0.626-Italic.woff2` | `4ad720fc84a440e99a2e7168fd555d2ff1d69413a524b811303fd2f37bd65024` |
| `assets/fonts/ButlerySans-0.626-Regular.ttf` | `d2cfc327caaa0cb4a1426f232af6d6d209b3f10ae0479bed6a1d64f38ad53789` |
| `assets/fonts/ButlerySans-0.626-Regular.woff2` | `736fcd08f3edade14b9e6256fc84f1d6ee621303f28bcf827d67e603d9bc41aa` |
| `assets/fonts/ButlerySans-0.626-Semibold.ttf` | `0f985fa4a8c9b93fd68e81ab1540bdd4728bca461a5787963211a21a63073904` |
| `assets/fonts/ButlerySans-0.626-Semibold.woff2` | `5231db76313fe70266b197d3733862e61ea6164d40ccfe7a0d149311d2dd081d` |
| `assets/fonts/ButlerySans-0.626-SemiboldItalic.ttf` | `0cbecdafa851a2744565b91566b0811208a2216621d7bea29b94135d2726b70e` |
| `assets/fonts/ButlerySans-0.626-SemiboldItalic.woff2` | `6fb9ff67614e4f8fce78773a144755c0bf5c924616345f93f0dd78cd301ccf21` |
| `assets/fonts/FONTLOG.txt` | `8689d6943baffaba05292edfe74535114fa83d1f6d30c7d225ae075ed3d614a8` |
| `assets/fonts/OFL-1.1.txt` | `863bba7ab7d16d6f0c37470f60b9ad03607ea12a73bbbd1317b0fd505e5756f9` |
| `assets/fonts/README.txt` | `84b43a68e61b394d690b95f5ca58d51ad0c35878a24ecbd4a680038378d54706` |
| `assets/fonts/THIRD_PARTY_NOTICES.txt` | `df63ad80acf18f06440975818dfb22f526dda320794f639d034125172538b1b1` |
| `assets/fonts/VALIDATION-0.626.txt` | `ffe23fedf47e3f1d51a4e87bf147da7b19ac180c806518faada8adfbaa4b1c94` |
| `assets/generated/tokens.css` | `5799c42843a2d0a5c39e803285ed9b6363cae458c8fb166515eb96d162fd9ec7` |
| `assets/icons/archive.svg` | `cf161abb7df09faed9bccb69e17efc0c85b134b4a522d6654c45201e3706467c` |
| `assets/icons/arrow-left.svg` | `f86261b82b6c3df65ab8f027335d56dba6cf3131c76929398d59d0da0bfb3cc3` |
| `assets/icons/arrow-right.svg` | `b9961b118f5627bb77b489e57f106607380d9a240e86da37f6868c53ae9c9010` |
| `assets/icons/arrow-up-down.svg` | `b53019824302c6aea237fc64a16696d3e884b75d728ebffb3f0ccd7c2388118c` |
| `assets/icons/bell.svg` | `22eee821e457234d522d88f4e94ebbea116ef98684547880fb87a064453856f0` |
| `assets/icons/block.svg` | `dc701131d77c12ff65f8ea1dc40aa560072cc654d4731bdc6c3aefd8e97487c1` |
| `assets/icons/calendar.svg` | `9a9cc1995eda1c9306b831b4b4e6143d8eff858d96912294828169c063048bc5` |
| `assets/icons/camera.svg` | `df02deb0b63ad4b6e122edc142adf10c3c84468f1387b79ffa6d2a515cc7cf2d` |
| `assets/icons/check-square.svg` | `52aa916993e709ee1f5510463976c914e73e90250e5ccc4be70f04e4eb3b0b24` |
| `assets/icons/check.svg` | `3953c377a49c920265660c2d5bf931774926494ac5efcd10d01c7aac13943962` |
| `assets/icons/chevron-down.svg` | `38e65b48c1e006483551dfcf742f20cf63505cd35fb6a5c2b25084ff7e3565b9` |
| `assets/icons/chevron-left.svg` | `2fd5cf77e29abc9e2cc1b4865cb7e5ef00b0d1ac5e3c98d02a1ac6834649e646` |
| `assets/icons/chevron-right.svg` | `3879fe334bb7d761e670a7172dbc535b6b634ff78a725b7060ab346783151fc0` |
| `assets/icons/chevron-up.svg` | `c817de8f05743addb7f47a84573ca8b10afb4755b536a588aae592dd1cbbf34f` |
| `assets/icons/circle-check.svg` | `3fa65a65dd97fb9b3aa68ec61a478e9fec38e6bc5a5f2ca3074efe114c922894` |
| `assets/icons/circle-help.svg` | `69914710a241d634cfa519383fdd96168525ba885762a6801c4e7d876527d153` |
| `assets/icons/clock.svg` | `acf0fcdb418356b28a9f6409b4af80556b09d0b91f9a4626404718988e111bc3` |
| `assets/icons/copy.svg` | `43a196b715896b06fbdeb61bfb7218400a08721e951aa5d0ed5de0b132c46d7d` |
| `assets/icons/download.svg` | `d8e81a1f9c9c8e6c46a4d42f3489461b6ac34475f72ba4b5aa998362a75084b4` |
| `assets/icons/drag.svg` | `852691c116150bb901347f85b3a3434107ad5ec6eab3769968b455390f9c8791` |
| `assets/icons/drop.svg` | `c200a1b843f6a937785b1552f5074a58d28a37403ba59aec921db80b5a41c1dc` |
| `assets/icons/export.svg` | `12fc498ccab1403ecf3bb45fe695cf59d2de101470563df2c147df79fac58586` |
| `assets/icons/eye.svg` | `e3db961457292ae91a895e7e61143621da90f7e80ca3247eb9c6022f436ae98d` |
| `assets/icons/file.svg` | `f06efb89b828daec1dca7ef406e8829ec10b3c190c8e86b0bd2de14c15a4a9b4` |
| `assets/icons/filter.svg` | `f3ebb296b5543ed991d287c335a1a6a52face98a6cdcbbf46d8d7b16bb424260` |
| `assets/icons/folder.svg` | `42ce942bb5263b904c5560a9dc9458414f7429bb4f2c2156f6c8eadfac538024` |
| `assets/icons/hand.svg` | `c994c30df2b39264eae3f3a92876010ed408573fcf98d0647ec449115bf01099` |
| `assets/icons/heart.svg` | `38d863fcaf65b283eac5f90ac322455e5d99d5401b17d2a2c1c8b40c877b094d` |
| `assets/icons/house.svg` | `d25fb6197c5b5a1956eb894d9f3da066639bf4495a481f24a47aaf99402f0f02` |
| `assets/icons/image.svg` | `4eba3e45b0cd0750bb631fb98f381168f188c8ca290a0f11d00056788a306180` |
| `assets/icons/info.svg` | `bbf92e1d2d682c1e34ce40e433cc9ad180ecb9761fd280c9358de0c5e073619f` |
| `assets/icons/link.svg` | `a7c4c166ede8c89b2635e7546842c1fcb3d4156df103953fcdb4d133a17c1c57` |
| `assets/icons/list-check.svg` | `1c13cfe9b8c0222b91442fb58b0fdcd2d39b2240546bc1882068987cb1616fcc` |
| `assets/icons/list.svg` | `5ca9f5560f724014dee4593f1fd262f20fe21cb446a88b15864322bc00709d55` |
| `assets/icons/lock.svg` | `61c387edb960f8f932c3fe177dd998d9a32b10d7f121a5906b709d7445ab36a8` |
| `assets/icons/mail.svg` | `77c1df936427dc675647b5d0f9b450b78604f2a411c06f59e57c825643908c46` |
| `assets/icons/message-square.svg` | `856a6f2c0da6d090f3726ecd16a3b9279878f213961ddf5cef56f71a5f4dfc70` |
| `assets/icons/mic.svg` | `64ad366b5a1be09dc622e52835a686bd7bfede5e870ce0668f8a3477415a4b08` |
| `assets/icons/minus.svg` | `e7d7352faef80ab07591bb0c2dad207382020e3c744898839a712b7e6f35f599` |
| `assets/icons/more-vertical.svg` | `ec0ed34c4fd381a1aad564fd4589cff0be55ffd1f77fdb82518d7b860cf9cd39` |
| `assets/icons/move.svg` | `0961e9a9df076e4a725e0edfb55ba812561e77f4d18bf0c2f2810c9bb2efa204` |
| `assets/icons/nav-add.svg` | `039f65079658b8dce9dd089e10f8402ce3359c3e4ea892be3cbe2f73f359ddb4` |
| `assets/icons/nav-home.svg` | `a578ecaea9b79235445ca39760de8b7831341abeee031a89594dc5ea6f2c4cda` |
| `assets/icons/nav-more.svg` | `c4083aef7629e441b966e21dd3fa8740ff0bc6dc496e7ff553c3576adc44ef31` |
| `assets/icons/nav-shopping.svg` | `9097e89b774b972081522c4db3d4ba8b54b7c38458776102039b26b9808ce8dc` |
| `assets/icons/nav-week.svg` | `570e33c0f2cafc36a65c462878ff83bd46302230d0dfc4b68d369cd486a0cd30` |
| `assets/icons/paperclip.svg` | `306954cf36deb0190f64efa3d9bbf4206433ad3875a1534244213bcd6b213676` |
| `assets/icons/pause.svg` | `0da78f3a5482d0fa11dc62dc3d40c3b95b5965ba04ba41a6ff1a5bcb269cfb74` |
| `assets/icons/pencil.svg` | `fe02e1ce7ce066839f7b95d080b3b9990a15f0da6e97a957713771fbf9672565` |
| `assets/icons/pin.svg` | `65386a798275ec45cd97c474589a7fb3caf6d038378f855899e1c05009525137` |
| `assets/icons/play.svg` | `c5ad74fdbbbd6163e2dd9dd861bf97bd16669dd1e40340c1187943ddf31b9ccc` |
| `assets/icons/plus.svg` | `91c960cd589b4feb75c4009b7ecc393d7da8c534498d19c33d8eb250bec308d9` |
| `assets/icons/reaction-add.svg` | `e3d91c36d51c3f2cfb00d598bf602e5e21a559a17d847348e6fae1b08f612e3b` |
| `assets/icons/refresh-cw.svg` | `686de34b4c51308307815ac94996e2c86ef51e164987f1a4f805f790f0e2e46b` |
| `assets/icons/search.svg` | `ea2ad628a5da3cc4bf4015b58e185d84a9821f23d99e456cabc9330a923a5c48` |
| `assets/icons/send.svg` | `8e5241043f15c2e35f4121366ce277a2e61377cd90bb230bee6c004ab2ecf27f` |
| `assets/icons/server.svg` | `9e4d142c0500738dd2e188eea21ee06e8babca7ffd7db149251c1bfc53574b9a` |
| `assets/icons/settings.svg` | `ec92c7623ef2957b0de1250aeb2ea70d271f4fca261052cfcd1a7f0fbeb4d859` |
| `assets/icons/share-2.svg` | `ec6e9578c11cd2fcc56549ec062f89f7a1ee09c07b540f099ce9844ae66c4f23` |
| `assets/icons/shield-check.svg` | `71ea758902bf3c5da1c25c945cd645a241aba739405d63645293ba3801c3fb43` |
| `assets/icons/shopping-cart.svg` | `3f3f22643c6fc991f675ed531d94924c466aa395074fc4f8186fdaf740fd54c2` |
| `assets/icons/shuffle.svg` | `c4e424f45c343c8100847dbf073e7074812b3e66d4c550b2d2b759b6c4890fe1` |
| `assets/icons/star.svg` | `a56e43c990b8f22116a5c25628b984a62904f7246ea9b65d9affb4397c86512a` |
| `assets/icons/stop.svg` | `3f8e1f8a8fffe5ba9eec6541a2180842de805e71f076a1b1585c46603b974ee4` |
| `assets/icons/swap-horizontal.svg` | `081cdcc7db1dfa60477cc68da64d8e40b11ec242cedf245bb66f5b5afbbda1c6` |
| `assets/icons/tag.svg` | `52ff495d873c7a8269d5c578a09f696e62ca27dc21f12d240b4151f4642d5f76` |
| `assets/icons/trash-2.svg` | `1df8ffcca6bea783222fbac4401644b37a0cc76a98c46e580b183ff95169c8f8` |
| `assets/icons/triangle-alert.svg` | `0fd28c0cf073d41a25ece79bb3952af2bcd2d3e4b76074cc8248e5ef33c7680d` |
| `assets/icons/unlock.svg` | `4163946e11e1d809f0f2907a20354c2c873868ba246d5d5ff08f2ea3e0c5b3b4` |
| `assets/icons/user-minus.svg` | `29dc5f846acb3475cefacac3f6f76551bed5460339029c41441baabe2d5b33f0` |
| `assets/icons/user.svg` | `14a950331bb0157d2df5f9c15b3f45b8168b7df4352e5e3cc616be3cde776030` |
| `assets/icons/users.svg` | `016591ebbea8ed2a154c543c0a6ee0742d7ed7f7913e7df114632010914d9d87` |
| `assets/icons/utensils.svg` | `de1d721e3ea3a4808b99d19ecc8527fe4fc3d4739a0d5203886c46d159634bc9` |
| `assets/icons/volume.svg` | `0b030431c9b748ebad8d1871ed68a4aedcef63218fbd83b9de14a4780004f145` |
| `assets/icons/vote.svg` | `f270cd1eb328d1a7c8b0d52a20c1c27c8d736560ea388b930e9ebf5e94a6b573` |
| `assets/icons/wifi-off.svg` | `90d085f0a8a5c3d805c2e4581764e20353369060bf7f351a922cd73a63b61a90` |
| `assets/icons/x.svg` | `966b860fe25929778bc7213e5b0c9d6ac2605bef611c2ca5fb303c9cd54aebaf` |
| `assets/icons/zap.svg` | `9f65150beb5e8550ac1d810574474220396e2f0f72a8596f79be018db214a5f2` |
| `assets/illustrations/butlery-ill-bread-basket-dark.svg` | `6f9b5a5a2afebac602d2d9bce9e8efc47cb565d8ff3743b1bc08189ca61d22f8` |
| `assets/illustrations/butlery-ill-bread-basket.svg` | `fc4326e161d22d351057dc560da2dd7b75f8cef13f303a10d23ef91ff7844b14` |
| `assets/illustrations/butlery-ill-cookbook-dark.svg` | `83ef4a7878cc74b418dd4079a9a3ea4b8128d0ee9ada3b530930c0f7f0b05fdc` |
| `assets/illustrations/butlery-ill-cookbook.svg` | `8c8c2b4ce86ca99ebc0c4e9a334137a72935af20bbffcbfc11df3a20bd032278` |
| `assets/illustrations/butlery-ill-empty-plate-dark.svg` | `f2e55dd5759cb0929e2cc53349d97fe79ea294d891fbcd2bba7b1fd6986e9869` |
| `assets/illustrations/butlery-ill-empty-plate.svg` | `1fce33a45052f335c4cc4537bff873ba84417ad5a676e7d5a797e8f5b613a393` |
| `assets/illustrations/butlery-ill-grocery-bag-dark.svg` | `b0eeed53ee36d1d9749005796b5b170f3b62df81cbad6e889e88c9ce80c22759` |
| `assets/illustrations/butlery-ill-grocery-bag.svg` | `30f73deaf9bcf0ea9b40631326c846b87160e6c4e3f164aab071251e0d05cc51` |
| `beslutslogg.md` | `25aef6833c0ddc57d6d5239413c864c5edb60698c640975b0ac21ff51a6f2fd3` |
| `blockerande.md` | `eb45a32a5530169da8f92e55729b96c61a7de72d2e3b75521bc1e4930814bfb8` |
| `butlery-tokens.schema.json` | `3757e0005ea613416f00a73ac67a3d7303d46a9468feb0ca2f5dc553fa90891d` |
| `ceremonier-scener.jsx` | `087f2953e0b08391b4b56c59d89ca04d79148c3c4a43fff15b2955abccc6dc30` |
| `content-style-guide.md` | `cb4fe9e93fe8286a394570353c8fe0d57f39b276a6eaff647129cb857cb570fd` |
| `evidensmatris.md` | `6f6387d0e8a513d5ddae6aa2e60feaeb0016fa18473852cd86729ea442c2041e` |
| `exports/android/ic_launcher_background.svg` | `81044da47484b9cc4affbcaaecc26524ac7bcea67185bc46258c370291e09dde` |
| `exports/android/ic_launcher_foreground.svg` | `7fb789ae266c96e4193483deb33ada24be8f110d93ab6588aa2d2a906fb87327` |
| `exports/android/ic_launcher_monochrome.svg` | `a03249354c03d5723cec56a38ed7514384ab4109531da449a02268075d399ef8` |
| `exports/ios/AppIcon-1024.png` | `2bce7e0b683b3054285607fb19d3a58706b483a69ade344c1e90fcfed74b036a` |
| `exports/ios/AppIcon-1024.svg` | `671dbabd32d82447548055e7215ccaf4a98f3b64259cad8cb91c227954734264` |
| `fas0/LAS-MIG.md` | `5e99d40df92c4b5c68024570ce15d38bbd9037bb05978b7b71b61f28c18fde82` |
| `fas0/artefaktforslag.md` | `f69520ede848fac35caaa5f743d5d73b5a2e4f24b131b6b1fc64389555fbbcf4` |
| `fas0/baseline-report-SUPERSEDED.json` | `12e79a51948917b6481ae31192b53a751e86e42b64cd44b341a5c41518fcb3be` |
| `fas0/blockerar-fas1.md` | `5a8189af818cb65b73009bde3638a9d12902b3043c56b6ea7e1ff742c4ca20e1` |
| `fas0/check-manifest.mjs` | `2ebcdd900af7d1baaf5aed1d3b7c2a98c5459d402798c49e5ba62ae745aab934` |
| `fas0/kallauktoritetsregister.md` | `a275ab4ee906bc50f2995578ef1db0408675a2bd27e4efeb216d3ebb91e50527` |
| `fas0/leveransmodellen.md` | `e8f935f282f1a6ef5e96564dc783104e197752f5417c8819c1ae938092adebd2` |
| `fas0/run-verify.sh` | `8cfdac6f33d8683f50ad4ca962a0f849917e4911e998c9177ae0587640cb36d7` |
| `fas0/verify-delivery.sh` | `b793ff7225563b71520127c41614a8c1f2e03f7f72780cadc63911d0e4d1e5f7` |
| `fas0/verify-report.schema.json` | `70687a2337ca6fe4a4419089983d8dfda52821b9af4799b4dabb03dfe9ac895d` |
| `fas2/affordans-negativa-prov.json` | `0139902066163acbd2accef31395fd9b3a081b1387c5e651255c17abf72701a5` |
| `fas2/affordansbevis.json` | `ecb7ac1ad2e7aa77f0dd5fa737adc05981ef9c30d5fcfe24889f901fb8577f09` |
| `fas2/effect-registry.json` | `3cc0615e726cd8e15eeec0c7b3bbbfb09f723d7c9b070e8a13682d15c5ef2fab` |
| `fas2/effects.json` | `aaaa1bd39313e0cabe08e23131e867688ddb3961eaf699e89e032f93c6f38367` |
| `fas2/effektprov.json` | `45ab1902893f061d70a2c1e25590685cb8a5885fb2da6a2ccb4886127f64c93c` |
| `fas2/gridmatning.txt` | `8972e840fef68b585a2b76e5ebe37d44a03bc3d3b6c7a7c63350fe53c9337726` |
| `fas2/gridmatning_test.dart.txt` | `6ee766862801cd83ab3d97d5d80f8399538882a58ef7cbdc6db9ef7c8460102a` |
| `fas2/hit-granskningslogg.json` | `a8fab8ef0847ca3edb1c4baa3cc89a336c71212191319f374d14831b62413c46` |
| `fas2/hit-hogrisklogg.json` | `665619357787cb6e897a9ef5bfd19741bbecf061065f054dea2a8fa2f235960b` |
| `fas2/hit-klass1-logg.json` | `60f408964d467ffef602c7ad421440facbd6436bdd2c6be8984ed4a1ae4a5b9d` |
| `fas2/hit-migrationslogg.json` | `12c8ba18ec02f442a395c4bcb32f686b8e540706dba761c51008d70644b81026` |
| `fas2/identitetsprov.json` | `d113891b9c0ac4a1b2cbf04b8ff482533e3f21996beb5d8bd27b591623650ac4` |
| `fas2/identity-collision-baseline.json` | `d5d133fd190b0e69256a199316169c5147bb2e46a14be8ff2dde2f285f39a5fd` |
| `fas2/ikongeometri.json` | `27bd32b81bf742d0fdf9da220687d15b5aae677c82d3b915ccb297eb7da4e7dc` |
| `fas2/kompkalla-r02.json` | `1918f7677d59587ab554ea973865c93ef30c35201ad9e7b704e49c16df43622f` |
| `fas2/kontrast-avstamning.json` | `8b400496e917a453e2d2fd4664921a2ee6d83faa75c4b0ba3836ed14f590f7c2` |
| `fas2/kontrastprov.json` | `453d9d62ce512d55bff07494a9eccb65f76a424b26b498c15608f9f6d461001c` |
| `fas2/nav-add-delta.json` | `0a8748d9f2059c0dc9e187db3824d62f691872cd456f24fca2df370fccc8f22c` |
| `fas2/negativa-prov.json` | `5ac71e2542a1c9b66427a154f591650f9da433e035e8f5c89d512e520cf658a0` |
| `fas2/r01-baslinje.json` | `d0f89a18c48f6d0e159f64b8f487c9417d26cc2272d06cce77aef58f0c2ca61c` |
| `fas2/r02-baslinje.json` | `ec751bef19c9d3b3f91ebdbba06eaabdc336bd26029aa08512402a7593ccc194` |
| `fas2/r02-coverage-batch-299.json` | `cd51234234098540aaafa8194c987a4c36bc01361f10d0e740042b469692eaf7` |
| `fas2/r02-coverage-batch-b.json` | `15fbb9d482f3e47454d05d7b2805dc494d5b2f0ad7ffac226786bcf5e74eb775` |
| `fas2/r02-coverage-batch-d.json` | `8934ea1db9690fe23bfb1306c114ec75c4b4b758a17cf4232f288dd9930040cf` |
| `fas2/r02-coverage-batch-st.json` | `28471e2f8b5a882d050d9adb547ff776e35e8960c35b00feddf4673c0c591139` |
| `fas2/r02-delta-44kontraktet.json` | `6ae99e247759643ff9f46af843591ef1dea12a24947a3f16b79d9b446cc926bc` |
| `fas2/r02-delta-rc04.json` | `30c70be28b2e3de0ee2a0d65670630e1e967fea5d31b13ef8cd6b8828c32432e` |
| `fas2/r02-delta-rc07.json` | `d0f053efdfb574a05b1da0e31f80ac84d8c483941f6796633d285bf293093796` |
| `fas2/r02-delta-rc09-rc10.json` | `1dcd636528c21a4b0d1ef9a84024e4b98e0fadadfcbe9f9e350135efa701b692` |
| `fas2/r02-delta-rc11.json` | `07878fdb96bad56a3e28cd94affd7d7e9d216705350ce23cac4a26c333e2bdd7` |
| `fas2/r02-delta-rc12-installergen.json` | `198236f21f220d7fcaddb6f5a7d9a3799e606eb95da90f29e0196c8bb8cc8af1` |
| `fas2/r02-delta-rc13.json` | `ed3f4e8ed855b3756e31cf245e0126e8ef7d6d36799561d392d79b473d34d7fe` |
| `fas2/r02-delta-rc14-15-16.json` | `c187416752652ccafd65cb9af376728eb179c554e8c1546ce7116f9b01f83966` |
| `fas2/r02-delta-socintegritet.json` | `31501130b4339bad195035ad3e310c642c0e4103464006b1e72054a6136e9854` |
| `fas2/r02-fix04-logg.json` | `a76fd39a7266255ff27741514841d78910ceb56cee35f6b8648f42197a27d12c` |
| `fas2/r02-fix0910-logg.json` | `ff3c355ac8d37733ceb03a29f3bd09ba6187ee822cead5006141b6dc21359e80` |
| `fas2/r02-fix44-logg.json` | `7b649c9a69cc9fbfa0b82a98394f88c442baad389275f5352721beef05ea80a5` |
| `fas2/r02-fix6-logg.json` | `e266c08e46bda22846b4cd6b82209b1cc455cb7d6fbd0b7bce9bdc779adfbbd1` |
| `fas2/r02-monster-613.json` | `a28cfbd08955bfeda04e9c94b38467286742239ef685b15809143472db24d82b` |
| `fas2/r02-partition-667.json` | `148e6aeda18c445a3f571fc6fc1a2a48d379cf0b9f65385d7be43763333d05a4` |
| `fas2/r02-rc11-matning.json` | `0aa2386aad74afd56f38d378947c16be3d6e2e73384c5a31722e683c3957c4c0` |
| `fas2/r02-rotorsaker-2.json` | `f07cdad43cfd7986ff3a22b0c7e0ee7c204beb11ac1338bfa96e3824fa6ccce3` |
| `fas2/r02-rotorsaker-3.json` | `9926dd3441752a3fbe02db5e03b53b175172fd8c560c82368d989f901db2823f` |
| `fas2/r02-rotorsaker.json` | `b2ad1b9d988bd8a1a7bdbacdbb37209b3309d25e81d422878e13c7e55a88d3c5` |
| `fas2/r02-snapshot-299.json` | `0db432967082be9a0241987d2912efba44837fc9954c62ba5a15386fe6d016cc` |
| `fas2/r02-snapshot-batch-b.json` | `e95c5e15aece6133feecb74e6dfd8ae5cb076fe6cb2dbab915855ab9c7540ad8` |
| `fas2/r02-snapshot-batch-d.json` | `e5d2a59995aa0567a6bfa10530b5c46316fafc68a3ba434eb2addda2be3a3d1a` |
| `fas2/r02-snapshot-batch-st.json` | `8ab46c4a2434451d7ac45a67dfdfc499f6ed51665d31cc33a0c0db9c7edb31fc` |
| `fas2/r02-snapshot-hogrisk.json` | `a9f7a54faed517b3e47400e4a9714de341a6dfc69a5a38f2fbdb367d69b77366` |
| `fas2/r02-socintegritet-scroll.json` | `c0f21306572877f7888543f722d6896b229c22ae1b2488610037cf06fa2f5590` |
| `fas2/r02-unknown-inventering.json` | `b5c81762f452b027814d1ca0b46fcb52be5aae3dfa6ef8a9346c24801a36cab3` |
| `fas2/r03-baslinje.json` | `f76b4f37b6bb52ece683c61621670a0b37173be3c74acf1da7bfd992b7e8c702` |
| `fas2/r04-parningsunderlag.json` | `d82a227cf2f2b978b42e9625365027bdf9e5b41136808987cc61e0a46cb4fa55` |
| `fas2/reproducerbarhet.json` | `85b244b9bf2d33831d7df56aa61cb5a24887aed3b7d7b095314be792022a726c` |
| `fas2/residual-r03-triage.json` | `976cacef6ab24c6bca869627862cf1405960073600e1399ace2ce3ad5289f220` |
| `fas2/scrollbevis.json` | `489415bd2ca8a6999cf4036349cceef8502d65d1f9917ccc4c3fbda07a1a3408` |
| `fas2/source-root-cause-map.json` | `a59b0dcaf2554fa49bc347a016fa1e0cd3f496c66e7ca4410c13c144f52d2bd1` |
| `fas2/src01-productfix-delta.json` | `e89521e8946e1c71cdceaa20fe7e818f7e5e104baf2a6054f1bd3a5175a6ef6b` |
| `fas2/src01-synkko-delta.json` | `d873ff5957949bfb6dc25d6941a83e8d52e058b8eb91cf9fd8434fad74d0e4a8` |
| `fas2/traffytepopulation.json` | `7dd87cef33d2010c87d46cd3f0e72d0c0b8b47670732a1bf7418b82c1bd2b67e` |
| `fas2/traffyteprov.json` | `d924ef9714321effcc1d7f335afcc6cc33faea10e303b7beed510e0560893600` |
| `flows-roles-budget.md` | `d9d66bc1669e65ec4f9769efc0b7b66885b4e8252e6dfb7345ce0c8da19d22f6` |
| `granskning-v12.md` | `0e1f0409c370e9a82dda87ae43379660c3b404e5ff2de5089f0fb69262da7d37` |
| `grundgranskning.md` | `019015ca6aca9fc50b54e5769b2099f410dac33e1f6d3f215546932be4cc1728` |
| `icons.json` | `fa46237fdc7ef51b4f46885144e1480504bc65230c63bf484b669975355f0cc9` |
| `korsgranskning.md` | `a5804bf9a3b8ff385d83b52d6c042e982ca15f7f1fc99f4e2317ecf6de80e566` |
| `layout-contract.json` | `d8b9683b373a3e142456890d177285c52307ccd433908f30c8e0592b35648431` |
| `legacy-api-contract.json` | `d80c3482657f2698a28d98f76fde20209373e7864d83017021a874fd7c004618` |
| `legacy-api-contract.schema.json` | `0196feab113bc269adc411eb4c60e8869b293ce658d0908959cddd7b7ec670ce` |
| `leverans/.thumbnail` | `9db713d1676e3e790a5914b648c0487f8a98b9014167c28251967c61d94d3d48` |
| `leverans/Butlery Fas 0 leverans.dc.html` | `cd3f24aacd6a45c4ec21cddd66f5aeeffec8badc0482f71277c61a2f26a8d97b` |
| `leverans/Butlery Fas 1 leverans.dc.html` | `bf0cb107e99d7b7d174ed32f6ade640ed2ecfcf48d05ea21e5fd911bed9cfb46` |
| `leverans/Butlery granskning och implementeringsplan.dc.html` | `76ab6fe3c1a833d5c2345b9391464de2446da52d7483e488facd5b38a05060fb` |
| `leverans/Butlery styrdokument modulart designsystem.dc.html` | `668514af38a383621c32f81b10dad4331b016fc2683b42237065198e5f0b10f0` |
| `leverans/fas0/DELIVERY` | `d9b3ef4a66ffc0c8ad97ac7dc80d0ec25cf19763c3448e1815cde9d6d935edd9` |
| `leverans/fas0/LAS-MIG.md` | `e40ced969555e5342132bf5fe27775e7c844dee2bdc2a5e667609737d26f2aff` |
| `leverans/support.js` | `8fe7df74405f3c55f49b7249c74ea1397e65d07dea2b1bd3b4a489bec2e28cbe` |
| `leverans/uploads/Butlery-arbetsorder-modulart-designsystem.md` | `4606e0ba64e57025713d717ed2415a0fcb3d541a7f9b74f0ed570efd821bd52b` |
| `lib/theme/app_colors.dart` | `88d091799771f4178ccaa1912deccbca3e06689e761807300059fa29ade5d8c8` |
| `lib/theme/app_text_styles.dart` | `4313702975dff44154804260b427404ddfef250eefe6cd0dfd0b0f343a68be98` |
| `lib/theme/butlery_tokens.dart` | `ef697346e89ad4e1a9c3023bf299e70196dc8074dc8cc97f3865685c652098c2` |
| `luckor-etapp9.md` | `58924563be83c9212fc92fe6a115ad6b18a644be208a7cec17192af62bdeb62a` |
| `migration-gap.md` | `42d5591b9bf0141cbe75586c722dcaeca55f8ea205b2ed9354762d4a56957739` |
| `plattformsmatris.md` | `c99f43258bf41b3800a502ed4484700e977e3c19354acf8acc9d0d77a3233518` |
| `produktregler.md` | `1892ec01d282772e343db4884e7645401acc3dd9c8db4497055ba6178ab542d6` |
| `selection-contexts.json` | `f88154ef9b9b7438997658efd4564fb4f08f202c6e6ebc09f713386f39552d2e` |
| `selection-contexts.schema.json` | `859ee6e11fa9514248ab48831ab5096465ca08e05288a5edb731777e00e4e5d5` |
| `source-authority.json` | `0442c2bcd8b4e9ba204858179e459e948baa89670a61678165e57243b86a0d17` |
| `source-authority.schema.json` | `87968355dfeefc13f5d78f6db00702618c42a04969da9021888e1a650d41926d` |
| `support.js` | `c60c49083997f51a592df118c0068475337afd20b8cfd8e1cd9d5eb0c7e254f6` |
| `testmatris.md` | `a16098a17dccf5a82acd4297b7ef26a738584a4c2914ac263b4a2113deaa6c4b` |
| `tokens.json` | `444b332bda5241a5e6450d3ee6a5f7e3b76e9e8af4b06a4616ddec7478ae1f02` |
| `tools/README.md` | `759f70a35c33d3ce2824c37ecda40724b3f2e6fcc1ab7b4cf976059f5b872051` |
| `tools/affordance-negatives.mjs` | `34ed8b432c37b7db1f3e357861c07801d738708e55f346ba30f702a30af6245b` |
| `tools/app-theme-map.json` | `7d2b2a1e90ed24b97715ec4decacc2b9ed4d5b5fb10dc52f398e922368cd2c7b` |
| `tools/app-theme-map.schema.json` | `540c09035681771786f7884abb098468e3382682f1e5dde6e98b9e2a829fd387` |
| `tools/artifact-contract.mjs` | `04b506fe6cb2f281de72bf389fa7382fbf68063dabb971f8ce84fe93363e7712` |
| `tools/authority-contract.mjs` | `7479d2ebd3496f4315fb98ed1e0cb006eb0780acaa824616bf47c214583fdad9` |
| `tools/build-delivery.mjs` | `fcfc81f8a1776576fd85e5e2140b0f55483efa8ecef36d87a0aa89d16b7a5d9d` |
| `tools/check-app-theme.mjs` | `3ec46efe91680b7050662962c1f117d5dc9a2653ffd1f9437a67a0a72217b745` |
| `tools/contrast-baseline.mjs` | `113856d641b98e32dce5d54979cb5f8110ef478d1581c4b0e63694a96524ac9f` |
| `tools/contrast-fixtures.mjs` | `11fb98b25e831ffc86998861a95703f46cf4117d7a997efe33fd4d26f3379617` |
| `tools/contrast-reconcile.mjs` | `94f6d84d9f0881b989bc5fee545f6f89bf5522d2505aebd299aa6cf15eb52489` |
| `tools/controls.mjs` | `6200d355c3198c9fb3e226943baca66a1de467f65566d77f9ec232555ce82088` |
| `tools/effect-adjudication.mjs` | `a854723b3b747bcb88f0cfc939300d8607db1d00485314a32c150f0ce780f2b0` |
| `tools/effect-fixtures.mjs` | `f85a2e184a7f0741e0096ea6abedacd29ee3b3bf526e12104e18378c12cb7f0c` |
| `tools/effect-report.mjs` | `61c1290052d707d1b13913987682a5835653d2ee7b18cf3ae50ff3c304f5e84c` |
| `tools/finalize.mjs` | `74fd11be650ad6a50a4c6817c06bac45dd1815c97faf524cd59c41f91ef0afd1` |
| `tools/gate.mjs` | `02917e6f14ed023585a1496630ba68b1b9dea5109ab991f5d1a5a931195ba4f0` |
| `tools/gen-app-theme.mjs` | `f07136386c267f52bda54a0e5b14523fa41facb615f276befc3b9c140f17bd01` |
| `tools/gen-artifact-proposal.mjs` | `6f0541b35c99c99e55432cb34d8b6c5188feca7297f728b148ff28bd9bc1b2ef` |
| `tools/gen-authority.mjs` | `6af83d88709b2ea93d89c22b4d5a4ffceccd0980418a8b126f88b06d8954e32b` |
| `tools/gen-check.mjs` | `f52d62056ee0b58cb2f718f64a57ce422fa73fd21079e9dc666d5307b51f31d4` |
| `tools/gen-counts.mjs` | `d74c3921589f23e7ec5d3d5208565677b04daa7833ae3f6af65c7d522fa869cd` |
| `tools/gen-css.mjs` | `723681243b90cc2703aefc9874d6421b248940a7c6884c316bc23b7daaf24d1b` |
| `tools/gen-flutter.mjs` | `112c73ba2c1808d845c692d26145854a22bfb89f9e7a9b3098c64742a92fd984` |
| `tools/gen-header.mjs` | `9c3b95d6d5e0a4f9e13d4943df07aca82c113eae55cf17e3b93800e59e97d508` |
| `tools/gen-icons.mjs` | `25e45becf2b0c0dd538dae54f7f0b74d2cd6ddc9095d9bd2b2b95f8f44e291ea` |
| `tools/gen-manifest.mjs` | `3572f9b1a2d63ee9ffdc605d7c40d903276a7605753ee21dc6d6170ee458b0dd` |
| `tools/gen-report.mjs` | `8e32d2530c1bf94ebc032f626e58764f99b8ec8f965633cbcf4d9fab082d432e` |
| `tools/gen-schema.mjs` | `1d276054d4fb6976fc8e1005626d23467c4c21bb5d48996016e883312cb74a84` |
| `tools/gen-targets.mjs` | `ffbef2620ef4be264e16dab5432c65fb80d24422eb8c0f3d9e512324f82e8e9f` |
| `tools/hit-baseline.mjs` | `ee7b37d71b92b9b5c10c837a050963d792a7b0d22837d4e37f154d35aef89814` |
| `tools/hit-contract.mjs` | `c0f29eb0cb3ae8017b70a3fea31c037390749491c62043a465d6d5025b77d43a` |
| `tools/hit-fixtures.mjs` | `26121493020c91084d81863fe70a1fb5d2add6af0340c92e7a231ae0f9d70216` |
| `tools/hit-measure.mjs` | `fc5427c382cd90495a16cf501bf1c73f60b2a90b2b8f525d6e9f37901a48cf8a` |
| `tools/hit-population.mjs` | `e9b78e6d1ad9b38fa5bf6d8560961629ce2f647fad7ab33f28cf226ecee7bffa` |
| `tools/icon-geometry.mjs` | `650276031635e06c81f678a89464c4baf8242b02bb45846bdb49a430822da62a` |
| `tools/identity-audit-lib.mjs` | `3c6cf596618e27ef724be2f59c15bb30bafcc3efdfdae82e572319864ac5a51c` |
| `tools/identity-audit.mjs` | `7207bf9d5259982f3c957a4d2e58b2428eb69eb9343c2fee4f05b7f1ddb8e7e3` |
| `tools/identity-fixtures.mjs` | `86c012427679bf2b61c584d77b5e9960b4a6c2bec2aa11d50a4bbf2a57abc15c` |
| `tools/identity-v2.mjs` | `9137bc7cf0a69dac41a768e6c12e4feaeaf8f49bdd2fa8d2971a0abaff1055d4` |
| `tools/lint-controls.mjs` | `07350d4dd8b167c772f9ca145cd69b92ff0418632c2252d434b7d9ad59f6c244` |
| `tools/lint-core.mjs` | `3b2a022f92648daf14b34d99cded4175ec3a95489570efc03be11fab2262ec20` |
| `tools/manifest-contract.mjs` | `e5b69a41062031b0c15868d4de9673d7f3645256e3cb5c8da66ea79ec83c368d` |
| `tools/metatest.mjs` | `29e5741faad10c4c250afac5c4a308d0f9ffd7a90ba681cf159ceb281bea1165` |
| `tools/preflight.mjs` | `3fe3bfa0e6f92fcb71ca5d19aa2c8e5e9df307f80eb3c8fe4dee09f173d5f3af` |
| `tools/preview-affordance.mjs` | `d90ad9347cef19d5077f9475e0a0f4c01ce82345cc96929fe9a662831baeb34a` |
| `tools/render-analyze-lib.mjs` | `5608257ad1b50b6487b0a0b8958930bf07fe4c639e80a6b08acec3707322a6a2` |
| `tools/render-analyze.mjs` | `43d16c95a2aa622fc6d63e3a2b41e31c2a2ffb135bc31dbcd3533150374eb428` |
| `tools/render-measure.mjs` | `073dab655a27255cc5172a115f50258497d3346d9a3e5c37813bd3073253aaa5` |
| `tools/render-negatives.mjs` | `10362b2febe71fc62c34b78965b0c99902dca396dadbda1ef708dd5a8eff6c69` |
| `tools/render-neutrality.mjs` | `54275336bdd61a904a3c111d753dc00b7d8c1a42e9c6954524328163c62ccb51` |
| `tools/render-probe.mjs` | `cde2604382b5ef4e7f60297dd58156dea66b2908415ffbc358584f1f0907a697` |
| `tools/render-repro.mjs` | `c01847106337b4f6cc744350f150ef54919ab925928dab19423897191affa2c1` |
| `tools/report-logic.mjs` | `f5a83590d3c99ae6deba764c5e9b50f1c25cf26bdda717bc220726694a77203a` |
| `tools/repro-check.mjs` | `7aefb37dd9ea18a37e20c0e52d0bf784b0e5515a40fbbb2058d9672c2e09a0ba` |
| `tools/residual-triage.mjs` | `527c05bf0f4129ad46ebbae49fbce7d165eda39003461916643061fa8b33a18c` |
| `tools/run-complete.mjs` | `a3884fe3ebaade9af0eca6789160fe11d2ad249ccd9ebcce517f17bc9f6a3bc2` |
| `tools/screen-files.mjs` | `d975c827273def112992f5ad6b1269817fffc6efc3e882a7d41d0d4269735e48` |
| `tools/seed-artifacts.mjs` | `7eb13560d086f7a1f31ddf95f62881fa40e1afce065793ff2a8bb56795046f4f` |
| `tools/selftest.mjs` | `f0a642cd4868df70eef74217f2ad5baddf2f8f9cf723be37e054261fd798d183` |
| `tools/spec-lint.mjs` | `520964df0ad36015cb3afce41ec8f89bd54dd6bb9d345ce47c7cd3da8075503d` |
| `tools/sync-icon-paths.mjs` | `7e8e9836aa79f545f95c381810df3a3fe68f607c652e36d6718d4e9f1f513de9` |
| `tools/test-generated.mjs` | `174f65e84f5cc6bee55b75df2ceb29e2ec4957ad397865bd6af65cf472eb7002` |
| `tools/testkit.mjs` | `59ad0de4f40fa319d23ab05a7548bf3328abc935680f136582b735f838a6c17a` |
| `tools/theme-pairing-lib.mjs` | `dcd07fd801a0c9d4e82dbf3bf50602d4ecf5a0aaf9905412584d93b2daa5f72a` |
| `tools/theme-pairing.mjs` | `a89363103ef0a7dcb85f751f238babaf2a9e769d033cc342ab12c326858bae31` |
| `tools/verify.mjs` | `84fe21ec973788155bd8f6dfd40450a89e9e18df3bd1b523592a27d97d5f6464` |
| `tools/version-read.mjs` | `931021ed5eca2e9a28987392b7146e2064b028e65a5038b7b1fc4b310262c474` |

## Leveransytan utanför reporoten

| Fil | SHA-256 |
|---|---|
| `zip:/.thumbnail` | `9db713d1676e3e790a5914b648c0487f8a98b9014167c28251967c61d94d3d48` |
| `zip:/Butlery Fas 0 leverans.dc.html` | `cd3f24aacd6a45c4ec21cddd66f5aeeffec8badc0482f71277c61a2f26a8d97b` |
| `zip:/Butlery Fas 1 leverans.dc.html` | `bf0cb107e99d7b7d174ed32f6ade640ed2ecfcf48d05ea21e5fd911bed9cfb46` |
| `zip:/Butlery granskning och implementeringsplan.dc.html` | `76ab6fe3c1a833d5c2345b9391464de2446da52d7483e488facd5b38a05060fb` |
| `zip:/Butlery styrdokument modulart designsystem.dc.html` | `668514af38a383621c32f81b10dad4331b016fc2683b42237065198e5f0b10f0` |
| `zip:/fas0/DELIVERY` | `d9b3ef4a66ffc0c8ad97ac7dc80d0ec25cf19763c3448e1815cde9d6d935edd9` |
| `zip:/fas0/LAS-MIG.md` | `e40ced969555e5342132bf5fe27775e7c844dee2bdc2a5e667609737d26f2aff` |
| `zip:/support.js` | `8fe7df74405f3c55f49b7249c74ea1397e65d07dea2b1bd3b4a489bec2e28cbe` |
| `zip:/uploads/Butlery-arbetsorder-modulart-designsystem.md` | `4606e0ba64e57025713d717ed2415a0fcb3d541a7f9b74f0ed570efd821bd52b` |
