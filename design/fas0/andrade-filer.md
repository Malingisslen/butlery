# Manifest · Fas 1 · femte vändan

**Genererat allra sist**, efter att de fyra genererade kodfilerna regenererats ur tokens 1.13 och `fas0/kallauktoritetsregister.md` renderats ur `source-authority.json`.

**Reporoten** kontrolleras med **set-likhet**. **Leveransytan** kontrolleras enligt läge; en leveranskontroll är alltid explicit (`bash fas0/verify-delivery.sh`).

| Läge | Betyder | Leveransytan | Fingeravtryck |
|---|---|---|---|
| `repo` | fristående checkout | får saknas | reporotsytan |
| `delivery` | uppackad ZIP | **varje `zip:/`-post krävs · set-likhet över HELA ytan** | reporotsytan **plus** alla `zip:/`-poster |
| `auto` | markören `zip:/fas0/DELIVERY` avgör | delivery när markören finns | följer valt läge |

**VALIDERAD LEVERANSROT.** Delivery-läget kräver att roten ligger exakt tre nivåer över reporoten, inte är filsystemets rot, och bär `zip:/fas0/DELIVERY` — annars exit 2. Traverseringen är djupbegränsad.

**HELA YTAN, INGEN ALLOWLIST.** Leveransytan räknade tidigare bara filer som matchade en filtypslista, och hoppade över breda kataloger — `surprise.png` och `uploads/scraps/undeclared.json` passerade. Nu räknas **varje vanlig fil**, och bara **exakta sökvägar** undantas: `fas0/verify.log`, `fas0/manifest.log`, `fas0/verify-report.json`, `fas0/kontrollstatus.md`, `fas0/ci-evidence.json`, `fas0/verify-exit`, `fas0/verify-chain-exit`, `.thumbnail`. Symlänkar avvisas (`lstatSync`) och varje post måste ligga innanför leveransrotens realpath.

**Genererade filer i manifestet** (sex): de fyra kodfilerna, `icons.json` och `fas0/kallauktoritetsregister.md`. Kodfilerna bär systemversion, tokenversion, generatorversion, källfingeravtryck (indata **plus** generatorns källa och den delade headerkoden) och ett **källdatum**. GEN-02 byte-jämför dessutom kroppen mot generatorns `--check`-läge.

Undantagna i checkern: genererade rapporter i `fas0/`, körstatusfilerna, ikonmastrarna i `assets/icons/` (räknas av `gen-icons`, kontrolleras av T-05), binärer och `exports/`, samt manifestet självt.

<!--manifest:files=113-->
Deklarerat antal poster: **113** (105 i reporoten + 8 i leveransytan).

## Reporoten · set-likhet gäller

| Fil | SHA-256 |
|---|---|
| `.github/workflows/verify.yml` | `18889417ae1fca6efa775b237641ad14aac9606d6f89c5c380255a49c4aae937` |
| `00-spec-index.md` | `a83d032477036b7c743de358081672c228a82ed0c2187f321072ad07e24aa9f8` |
| `animations-v2.jsx` | `33e9200b93f5eb416d294e1a1ffc6bebe75d2bee95817977a08fa896229be774` |
| `arbetsplan.md` | `326221917cb77f0db4595c909d09d8ffe762ee11a5ee43f710d78c95cabfa81a` |
| `assets-manifest.json` | `df7201da509c2359b5c35114a32a55755aa4647108cfb5824c1ae594144e64ec` |
| `assets/brand-colors.json` | `1cc1e0243b46309c56a2c2686c6401bfa200f1cc70fafcbc68dc99f973102935` |
| `assets/brand-colors.schema.json` | `7c16a20daa7be3856cbf48706940eeb065a44849cf8d6afd11fa4d9bfeeaf0af` |
| `assets/fonts/FONTLOG.txt` | `8689d6943baffaba05292edfe74535114fa83d1f6d30c7d225ae075ed3d614a8` |
| `assets/fonts/OFL-1.1.txt` | `863bba7ab7d16d6f0c37470f60b9ad03607ea12a73bbbd1317b0fd505e5756f9` |
| `assets/fonts/README.txt` | `84b43a68e61b394d690b95f5ca58d51ad0c35878a24ecbd4a680038378d54706` |
| `assets/fonts/THIRD_PARTY_NOTICES.txt` | `df63ad80acf18f06440975818dfb22f526dda320794f639d034125172538b1b1` |
| `assets/fonts/VALIDATION-0.626.txt` | `ffe23fedf47e3f1d51a4e87bf147da7b19ac180c806518faada8adfbaa4b1c94` |
| `assets/generated/tokens.css` | `5799c42843a2d0a5c39e803285ed9b6363cae458c8fb166515eb96d162fd9ec7` |
| `assets/LICENSES.md` | `17d5f6fbdf80c3ccee9e420a646c3ebb03ec7a188eacb7a42eaae857ac942b95` |
| `beslutslogg.md` | `25aef6833c0ddc57d6d5239413c864c5edb60698c640975b0ac21ff51a6f2fd3` |
| `blockerande.md` | `eb45a32a5530169da8f92e55729b96c61a7de72d2e3b75521bc1e4930814bfb8` |
| `Butlery beslut grund v13.dc.html` | `ce0aaa76a62fb6616d58e93fdaabd1c5b185bdf87ac11bfb60a91b3f7b324eaf` |
| `Butlery beslut kalendermatt v1.dc.html` | `8fb980fb2eb6c9805c14e8d1bc15421e3e57e5656df1d1ea735314b200f1cdb0` |
| `Butlery blockerande tickets.dc.html` | `dc8d379aaa1469f94d5189923972e6a498d5f5441e347e226dbef7eb19215e39` |
| `Butlery ceremonier rorelsereferens.dc.html` | `19cc633fbbfb4f1526430099e077557e8a6b0281e10fa2b1b02f51dc8a3aff9b` |
| `Butlery Grafisk manual v6.dc.html` | `3879f2b3451f47de109db76b05f4fd18361f7c1318bebc625c1bdeca6fbd2964` |
| `Butlery Komponentark v1.dc.html` | `78f27a546502c7d2a9cb99aa954d6cd8ba3b5d18f1694aac2d9db1496ff1ed47` |
| `Butlery Skarmar v12 del 1 recept och veckomeny.dc.html` | `b473330181de718ddeb92c6bdcd287ad7e3a9545055806c9333d67205ab6b8cc` |
| `Butlery Skarmar v12 del 2 familj och socialt.dc.html` | `8b104b62843ac3c902ef19e18b01e8da8b2901496717a0f6c5baf3bb1e6eb271` |
| `Butlery Skarmar v12 del 3 sok och skalbevis.dc.html` | `6287c368c3b3e0071fefc11ea24cb4c19b94a7160a12d4b7a362f5ca51ef5334` |
| `Butlery Skarmar v12 del 4 morkt lage och etapp 0-1.dc.html` | `11843dac0cd31072c8a137ab8affe5aac35aef30fec3b48092e6517d59aabbb7` |
| `Butlery Skarmar v12 etapp 10 bred layout.dc.html` | `aa09ad6633fa1519a1780d97b2553d42618a80a3396757a3824ef55f0f3fe21d` |
| `Butlery Skarmar v12 etapp 11 breda vyer.dc.html` | `fbfe3127fb9e3bb38ae1bd6fcb95d2efc6ba8f2e1ecad0d794021060c0bbc0a2` |
| `Butlery Skarmar v12 etapp 2 inkop och skafferi.dc.html` | `40811c3df142c84eae6406c1d7eaf0c90211fa9af2de2f59d5b797abab7349ff` |
| `Butlery Skarmar v12 etapp 2.dc.html` | `b8399244641dff623cbce626ee96ec133d14ab3fc0f02144e3ac3cf27293fdcc` |
| `Butlery Skarmar v12 etapp 3 onboarding.dc.html` | `5e68eddb5d0073e12f4b36c851c7df8fbe0f5f86d2fe05ef76f8d5e299b07b13` |
| `Butlery Skarmar v12 etapp 4 import.dc.html` | `515703b74dea670292295bc8239e8511d2264cb6c71139af7b9443ae15e05553` |
| `Butlery Skarmar v12 etapp 5-7.dc.html` | `956053b7d726a911f50c12575f97167b422efadd7d57a9ef1d4a5a7346061d4e` |
| `Butlery Skarmar v12 etapp 6 konto och integritet.dc.html` | `9b2a97a3eb9094440433f280e5ab338f1313bd4e59ad3e5ac0cfbff3d70bed2b` |
| `Butlery Skarmar v12 etapp 9 globala tillstand och flerval.dc.html` | `7dc8d002f638756aa48396476721cffc95177dbaeac87d2f51b03ebf4d25bce2` |
| `Butlery Skarmar v12 etapp 9 socialt och komponenter.dc.html` | `c906904b10eada66833c99058a4922c69351c17fc49e1d858e76bc82bec9f8dd` |
| `Butlery Skarmar v12.dc.html` | `c1b435cf7c470ebe31db64b82b5fc4ee94993391801130edee761f1540c893b2` |
| `Butlery tillganglighetshandoff.dc.html` | `d4f0ea3be4dcf1a4fd7dfe71963459b3085ab658f2a1ee12169c987410473321` |
| `Butlery utestaende beslut.dc.html` | `a42589af8458f36e700689d3daf8fb5be688ae04e607c5ed1e44743d8863e536` |
| `Butlery-app-icon-gradde-platta-R4-6.svg` | `5003745e69f7fb491a5dd5487f1f4a2e98a803d691efc9e826d05d8e1a3d78cf` |
| `Butlery-app-icon-monoline-R4-6.svg` | `09b3a6e2548ee1b906b81f2c5a22bb5f304fa09158dac1a6fc7544c1cb6dd377` |
| `Butlery-app-icon-negativ-R4-6.svg` | `4e4a7e673550dbd3c2c55d9c2757099d60d9c34101822d84d5cfc63995f82ffd` |
| `Butlery-app-icon-solid-R4-6.svg` | `f5e6739bfdf1fb110f630097a5733844d3bd2be23d3e19798f3e66f105e050d9` |
| `butlery-tokens.schema.json` | `3757e0005ea613416f00a73ac67a3d7303d46a9468feb0ca2f5dc553fa90891d` |
| `ceremonier-scener.jsx` | `087f2953e0b08391b4b56c59d89ca04d79148c3c4a43fff15b2955abccc6dc30` |
| `content-style-guide.md` | `cb4fe9e93fe8286a394570353c8fe0d57f39b276a6eaff647129cb857cb570fd` |
| `evidensmatris.md` | `0d9a6f3ad09b8461644eb7578a462c797495c24f1433308494b8436ac7c7ad81` |
| `fas0/baseline-report-SUPERSEDED.json` | `12e79a51948917b6481ae31192b53a751e86e42b64cd44b341a5c41518fcb3be` |
| `fas0/blockerar-fas1.md` | `bece3d1d1e15f0a57fddf882e7a58f3ed2c97021a31ff2d6a0655d2febd57518` |
| `fas0/check-manifest.mjs` | `977c1b4717ead3de0f817e2024169f617b5f34c74565138582d9b2a9e6535fb5` |
| `fas0/kallauktoritetsregister.md` | `43fd7373f260bfe5887cf3cb554584f59a238eb6b2d51255e81463320e4fb68c` |
| `fas0/LAS-MIG.md` | `f36b6774c9cf53c155ee3ca5e31d1672ad70495f0f7c2a0da4512381a814baf5` |
| `fas0/run-verify.sh` | `8cfdac6f33d8683f50ad4ca962a0f849917e4911e998c9177ae0587640cb36d7` |
| `fas0/verify-delivery.sh` | `b793ff7225563b71520127c41614a8c1f2e03f7f72780cadc63911d0e4d1e5f7` |
| `fas0/verify-report.schema.json` | `70687a2337ca6fe4a4419089983d8dfda52821b9af4799b4dabb03dfe9ac895d` |
| `flows-roles-budget.md` | `d9d66bc1669e65ec4f9769efc0b7b66885b4e8252e6dfb7345ce0c8da19d22f6` |
| `FONT-VERSION.txt` | `b9b7731a213a7f4ae7d36bb8a5bdbb9ebd91c4dd093b8d08443d3a397e92cbcf` |
| `granskning-v12.md` | `0e1f0409c370e9a82dda87ae43379660c3b404e5ff2de5089f0fb69262da7d37` |
| `grundgranskning.md` | `019015ca6aca9fc50b54e5769b2099f410dac33e1f6d3f215546932be4cc1728` |
| `icons.json` | `ba05efada07608a40cad09da0a8adf87c5f57d65023f66fb73139bc2953223c2` |
| `korsgranskning.md` | `a5804bf9a3b8ff385d83b52d6c042e982ca15f7f1fc99f4e2317ecf6de80e566` |
| `LAS-MIG-GRANSKNING.md` | `5305b92b1b958396e51e5985128f6f2b43f90415d8afa9445aa3548cb1fe8bdd` |
| `legacy-api-contract.json` | `d80c3482657f2698a28d98f76fde20209373e7864d83017021a874fd7c004618` |
| `legacy-api-contract.schema.json` | `0196feab113bc269adc411eb4c60e8869b293ce658d0908959cddd7b7ec670ce` |
| `lib/theme/app_colors.dart` | `88d091799771f4178ccaa1912deccbca3e06689e761807300059fa29ade5d8c8` |
| `lib/theme/app_text_styles.dart` | `4313702975dff44154804260b427404ddfef250eefe6cd0dfd0b0f343a68be98` |
| `lib/theme/butlery_tokens.dart` | `ef697346e89ad4e1a9c3023bf299e70196dc8074dc8cc97f3865685c652098c2` |
| `luckor-etapp9.md` | `58924563be83c9212fc92fe6a115ad6b18a644be208a7cec17192af62bdeb62a` |
| `migration-gap.md` | `42d5591b9bf0141cbe75586c722dcaeca55f8ea205b2ed9354762d4a56957739` |
| `plattformsmatris.md` | `c99f43258bf41b3800a502ed4484700e977e3c19354acf8acc9d0d77a3233518` |
| `produktregler.md` | `8e7b7cd9faaa64ac6ebaadb92b748ff253b2883831d036d6144ec25a99ef96f9` |
| `source-authority.json` | `584c48b544bcbbb740e9cb59f0ca140fb5f9fb077c14e5eb2515de633b41d311` |
| `source-authority.schema.json` | `f3fc496857d6a5ee2f6f79e9ae35a3d06589e2920a29be5d3a4b0be4358f8c1e` |
| `support.js` | `c60c49083997f51a592df118c0068475337afd20b8cfd8e1cd9d5eb0c7e254f6` |
| `testmatris.md` | `7da9f1a7038b53e553186a1fdeea041110ed36e5ccf885e716b8bf005c0dc5de` |
| `tokens.json` | `444b332bda5241a5e6450d3ee6a5f7e3b76e9e8af4b06a4616ddec7478ae1f02` |
| `tools/app-theme-map.json` | `7d2b2a1e90ed24b97715ec4decacc2b9ed4d5b5fb10dc52f398e922368cd2c7b` |
| `tools/app-theme-map.schema.json` | `540c09035681771786f7884abb098468e3382682f1e5dde6e98b9e2a829fd387` |
| `tools/check-app-theme.mjs` | `3ec46efe91680b7050662962c1f117d5dc9a2653ffd1f9437a67a0a72217b745` |
| `tools/controls.mjs` | `33637e081d8463b2776d044ced1a6e5e1f64e0f291133ae1e7a63105ca76590c` |
| `tools/finalize.mjs` | `74fd11be650ad6a50a4c6817c06bac45dd1815c97faf524cd59c41f91ef0afd1` |
| `tools/gate.mjs` | `02917e6f14ed023585a1496630ba68b1b9dea5109ab991f5d1a5a931195ba4f0` |
| `tools/gen-app-theme.mjs` | `f07136386c267f52bda54a0e5b14523fa41facb615f276befc3b9c140f17bd01` |
| `tools/gen-authority.mjs` | `a2fcc473b2490c4e4d5ac7749678e3bb47ddfadc21b94e189cac4733fec9a801` |
| `tools/gen-check.mjs` | `f52d62056ee0b58cb2f718f64a57ce422fa73fd21079e9dc666d5307b51f31d4` |
| `tools/gen-counts.mjs` | `d74c3921589f23e7ec5d3d5208565677b04daa7833ae3f6af65c7d522fa869cd` |
| `tools/gen-css.mjs` | `723681243b90cc2703aefc9874d6421b248940a7c6884c316bc23b7daaf24d1b` |
| `tools/gen-flutter.mjs` | `112c73ba2c1808d845c692d26145854a22bfb89f9e7a9b3098c64742a92fd984` |
| `tools/gen-header.mjs` | `9c3b95d6d5e0a4f9e13d4943df07aca82c113eae55cf17e3b93800e59e97d508` |
| `tools/gen-icons.mjs` | `25e45becf2b0c0dd538dae54f7f0b74d2cd6ddc9095d9bd2b2b95f8f44e291ea` |
| `tools/gen-report.mjs` | `8e32d2530c1bf94ebc032f626e58764f99b8ec8f965633cbcf4d9fab082d432e` |
| `tools/gen-schema.mjs` | `1d276054d4fb6976fc8e1005626d23467c4c21bb5d48996016e883312cb74a84` |
| `tools/gen-targets.mjs` | `3c6a4e4b34199c7296b88575a437e05fdffc9ff306badd2eefd0b27dfd3aec91` |
| `tools/lint-controls.mjs` | `07350d4dd8b167c772f9ca145cd69b92ff0418632c2252d434b7d9ad59f6c244` |
| `tools/lint-core.mjs` | `0c0430549a52685a4ea377454f3b476a02929a48142ac8bd9d51df150d7d1ca4` |
| `tools/metatest.mjs` | `1e72538bfd5b9e2e0f33acf291ec7195760f0afc353947e447a86277e6e073b0` |
| `tools/preflight.mjs` | `3fe3bfa0e6f92fcb71ca5d19aa2c8e5e9df307f80eb3c8fe4dee09f173d5f3af` |
| `tools/README.md` | `8c98b69e11e94391d883fc41cbeaffd1a5544e37eaa1e2adb767b0015fb93c6e` |
| `tools/report-logic.mjs` | `62b38358e6d8f77dd31a52ef6cde1061ec4a5d03b390204ec0ff51505b30258f` |
| `tools/screen-files.mjs` | `d975c827273def112992f5ad6b1269817fffc6efc3e882a7d41d0d4269735e48` |
| `tools/selftest.mjs` | `a05697e17c9fad74553373f7b9ee9e7774ce121c485ad8ad38f5af51f76b2930` |
| `tools/spec-lint.mjs` | `520964df0ad36015cb3afce41ec8f89bd54dd6bb9d345ce47c7cd3da8075503d` |
| `tools/sync-icon-paths.mjs` | `7e8e9836aa79f545f95c381810df3a3fe68f607c652e36d6718d4e9f1f513de9` |
| `tools/test-generated.mjs` | `174f65e84f5cc6bee55b75df2ceb29e2ec4957ad397865bd6af65cf472eb7002` |
| `tools/verify.mjs` | `a3ece40611040bb85c3b637ea0b00df618657429f6e4eb9df20b0d8937a3c211` |

## Leveransytan utanför reporoten

| Fil | SHA-256 |
|---|---|
| `zip:/Butlery Fas 0 leverans.dc.html` | `cd3f24aacd6a45c4ec21cddd66f5aeeffec8badc0482f71277c61a2f26a8d97b` |
| `zip:/Butlery Fas 1 leverans.dc.html` | `abb7efa772cb30785187bde3f3ec1169ac08569ec0893eb768df884975c6256b` |
| `zip:/Butlery granskning och implementeringsplan.dc.html` | `76ab6fe3c1a833d5c2345b9391464de2446da52d7483e488facd5b38a05060fb` |
| `zip:/Butlery styrdokument modulart designsystem.dc.html` | `b4f29ea1926acb92172ddd8e4ed6e01836829be1039ce2ee08fa8e7300a9ab65` |
| `zip:/fas0/DELIVERY` | `d9b3ef4a66ffc0c8ad97ac7dc80d0ec25cf19763c3448e1815cde9d6d935edd9` |
| `zip:/fas0/LAS-MIG.md` | `651e42c615166c7462b74a9539534c25e92b95fd9d99e14d314132dde2d770a4` |
| `zip:/support.js` | `8fe7df74405f3c55f49b7249c74ea1397e65d07dea2b1bd3b4a489bec2e28cbe` |
| `zip:/uploads/Butlery-arbetsorder-modulart-designsystem.md` | `4606e0ba64e57025713d717ed2415a0fcb3d541a7f9b74f0ed570efd821bd52b` |
