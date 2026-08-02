# Manifest · Fas 0.18

**Reporoten** kontrolleras med **set-likhet**. **Leveransytan** kontrolleras enligt läge; en leveranskontroll är alltid explicit (`bash fas0/verify-delivery.sh`).

| Läge | Betyder | Leveransytan | Fingeravtryck |
|---|---|---|---|
| `repo` | fristående checkout | får saknas | reporotsytan |
| `delivery` | uppackad ZIP | **varje `zip:/`-post krävs** | reporotsytan **plus** alla `zip:/`-poster |
| `auto` | markören `zip:/fas0/DELIVERY` avgör | delivery när markören finns | följer valt läge |

**En parser** (`manifestEntries`, `resolveEntry`, `artifactFingerprint`) delas av verifieraren, grinden och manifestkontrollen.

**Grinden reducerar om** hela registret ur rapportens rådata och **djupjämför** varje kontrollrad med `isDeepStrictEqual` — extra, borttagna och ändrade fält fäller alla, inklusive nästlade.

Undantagna i checkern: `fas0/verify.log`, `fas0/manifest.log`, `fas0/manifest-delivery.log`, `fas0/verify-report.json`, `fas0/kontrollstatus.md`, `fas0/ci-evidence.json`, `fas0/verify-exit`, `fas0/verify-chain-exit`, binärer i `assets/` och `exports/`, samt manifestet självt.

<!--manifest:files=100-->
Deklarerat antal poster: **100** (93 i reporoten + 7 i leveransytan).

## Reporoten · set-likhet gäller

| Fil | SHA-256 |
|---|---|
| `.github/workflows/verify.yml` | `6f6985b45f1fcc2f26ddf0d541c3477b77de0cdccdca46eab2ae30ebe271f3ef` |
| `00-spec-index.md` | `d414563c541cde7cead857de47ab724f38681983fc1569b35ab3d494757eaede` |
| `animations-v2.jsx` | `33e9200b93f5eb416d294e1a1ffc6bebe75d2bee95817977a08fa896229be774` |
| `arbetsplan.md` | `326221917cb77f0db4595c909d09d8ffe762ee11a5ee43f710d78c95cabfa81a` |
| `assets-manifest.json` | `df7201da509c2359b5c35114a32a55755aa4647108cfb5824c1ae594144e64ec` |
| `assets/fonts/FONTLOG.txt` | `8689d6943baffaba05292edfe74535114fa83d1f6d30c7d225ae075ed3d614a8` |
| `assets/fonts/OFL-1.1.txt` | `863bba7ab7d16d6f0c37470f60b9ad03607ea12a73bbbd1317b0fd505e5756f9` |
| `assets/fonts/README.txt` | `84b43a68e61b394d690b95f5ca58d51ad0c35878a24ecbd4a680038378d54706` |
| `assets/fonts/THIRD_PARTY_NOTICES.txt` | `df63ad80acf18f06440975818dfb22f526dda320794f639d034125172538b1b1` |
| `assets/fonts/VALIDATION-0.626.txt` | `ffe23fedf47e3f1d51a4e87bf147da7b19ac180c806518faada8adfbaa4b1c94` |
| `assets/generated/tokens.css` | `a63d5df71c2dd9e91199769ac44ad016d97c761969c0f37f442ee0df7373f4bc` |
| `assets/LICENSES.md` | `17d5f6fbdf80c3ccee9e420a646c3ebb03ec7a188eacb7a42eaae857ac942b95` |
| `beslutslogg.md` | `25aef6833c0ddc57d6d5239413c864c5edb60698c640975b0ac21ff51a6f2fd3` |
| `blockerande.md` | `eb45a32a5530169da8f92e55729b96c61a7de72d2e3b75521bc1e4930814bfb8` |
| `Butlery beslut grund v13.dc.html` | `ce0aaa76a62fb6616d58e93fdaabd1c5b185bdf87ac11bfb60a91b3f7b324eaf` |
| `Butlery beslut kalendermatt v1.dc.html` | `8fb980fb2eb6c9805c14e8d1bc15421e3e57e5656df1d1ea735314b200f1cdb0` |
| `Butlery blockerande tickets.dc.html` | `dc8d379aaa1469f94d5189923972e6a498d5f5441e347e226dbef7eb19215e39` |
| `Butlery ceremonier rorelsereferens.dc.html` | `f74dc38729fcb4c0bedc9a29f99d4201f149eac228742007bb467ae135652950` |
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
| `butlery-tokens.schema.json` | `78e0d013bbb0b53ae8c0c49bda730462fa495a166fee24d639ced4f96b8014dc` |
| `ceremonier-scener.jsx` | `087f2953e0b08391b4b56c59d89ca04d79148c3c4a43fff15b2955abccc6dc30` |
| `content-style-guide.md` | `cb4fe9e93fe8286a394570353c8fe0d57f39b276a6eaff647129cb857cb570fd` |
| `evidensmatris.md` | `0d9a6f3ad09b8461644eb7578a462c797495c24f1433308494b8436ac7c7ad81` |
| `fas0/baseline-report-SUPERSEDED.json` | `12e79a51948917b6481ae31192b53a751e86e42b64cd44b341a5c41518fcb3be` |
| `fas0/blockerar-fas1.md` | `e7efa82531a39ab880b8b55d2d601751473e869fa6079cff9ff5f4ad7e2ea735` |
| `fas0/check-manifest.mjs` | `bfbc4a22d97b50638cbf966642afb4616c019763c0c8027540cda425402240f0` |
| `fas0/kallauktoritetsregister.md` | `1f26c67d34a41eb4ebcc63078fb3d7c8d207593310fc6b9a8cff9e461daba163` |
| `fas0/LAS-MIG.md` | `f36b6774c9cf53c155ee3ca5e31d1672ad70495f0f7c2a0da4512381a814baf5` |
| `fas0/run-verify.sh` | `8cfdac6f33d8683f50ad4ca962a0f849917e4911e998c9177ae0587640cb36d7` |
| `fas0/verify-delivery.sh` | `b793ff7225563b71520127c41614a8c1f2e03f7f72780cadc63911d0e4d1e5f7` |
| `fas0/verify-report.schema.json` | `cd080a2b58d6d55c9a01567bc13baec269b1181c233a26a1468503b85234e2fc` |
| `flows-roles-budget.md` | `d9d66bc1669e65ec4f9769efc0b7b66885b4e8252e6dfb7345ce0c8da19d22f6` |
| `FONT-VERSION.txt` | `b9b7731a213a7f4ae7d36bb8a5bdbb9ebd91c4dd093b8d08443d3a397e92cbcf` |
| `granskning-v12.md` | `0e1f0409c370e9a82dda87ae43379660c3b404e5ff2de5089f0fb69262da7d37` |
| `grundgranskning.md` | `019015ca6aca9fc50b54e5769b2099f410dac33e1f6d3f215546932be4cc1728` |
| `icons.json` | `e4f8413cf68813648f01033b74dbcda2872a84054e19517396fe5c3087f351ed` |
| `korsgranskning.md` | `a5804bf9a3b8ff385d83b52d6c042e982ca15f7f1fc99f4e2317ecf6de80e566` |
| `LAS-MIG-GRANSKNING.md` | `5305b92b1b958396e51e5985128f6f2b43f90415d8afa9445aa3548cb1fe8bdd` |
| `lib/theme/app_colors.dart` | `fb0f74925366fcea5a303a55d8509d59e413588f244da8f81cda6c0f1351d285` |
| `lib/theme/app_text_styles.dart` | `3f4592a2fe387de911108477de8f5302190805593789636acf676be6aa3ac54b` |
| `lib/theme/butlery_tokens.dart` | `d87dba1bbe7ca8b2e608c76a591ee1ae0d01621e2f49e750c4d7f615d1d3f3df` |
| `luckor-etapp9.md` | `58924563be83c9212fc92fe6a115ad6b18a644be208a7cec17192af62bdeb62a` |
| `migration-gap.md` | `42d5591b9bf0141cbe75586c722dcaeca55f8ea205b2ed9354762d4a56957739` |
| `plattformsmatris.md` | `c99f43258bf41b3800a502ed4484700e977e3c19354acf8acc9d0d77a3233518` |
| `produktregler.md` | `8e7b7cd9faaa64ac6ebaadb92b748ff253b2883831d036d6144ec25a99ef96f9` |
| `support.js` | `c60c49083997f51a592df118c0068475337afd20b8cfd8e1cd9d5eb0c7e254f6` |
| `testmatris.md` | `7da9f1a7038b53e553186a1fdeea041110ed36e5ccf885e716b8bf005c0dc5de` |
| `tokens.json` | `e3f272bc3f95f752f93e75384da18ae9ae2313ac34c3c37f75767a8a0c6c5fc4` |
| `tools/app-theme-map.json` | `90a26dfda9e567d365ca6be42c1cc52001e996c4ed781252c7ae5851adac91c4` |
| `tools/controls.mjs` | `cd7fc97a7d1eee7019b063683bedb9566a4764f1631477faa2246608adcb87f3` |
| `tools/finalize.mjs` | `74fd11be650ad6a50a4c6817c06bac45dd1815c97faf524cd59c41f91ef0afd1` |
| `tools/gate.mjs` | `02917e6f14ed023585a1496630ba68b1b9dea5109ab991f5d1a5a931195ba4f0` |
| `tools/gen-app-theme.mjs` | `5cf80ac0fff044a1533a0d1ec8b7947dd322fb95a8962801179b548b9fbd98c9` |
| `tools/gen-counts.mjs` | `d74c3921589f23e7ec5d3d5208565677b04daa7833ae3f6af65c7d522fa869cd` |
| `tools/gen-css.mjs` | `43251edd5ed6a13db6081d61ca74f80f5cdd381ab22c72b324ee30c9ef115617` |
| `tools/gen-flutter.mjs` | `94f5c80a216bb10e238e2bdbc16ba7ae18b31a57e5d5fc323f9f367a78f824b5` |
| `tools/gen-icons.mjs` | `476acd192456259402668e655aa75c44bbf923c5ebc06c60bdb2f2a347bac178` |
| `tools/gen-report.mjs` | `d534a6b1985024203ebba2e008e91c6b46b7c1dc9b8b680bd9e1478f6d0b68a8` |
| `tools/gen-schema.mjs` | `1d276054d4fb6976fc8e1005626d23467c4c21bb5d48996016e883312cb74a84` |
| `tools/lint-controls.mjs` | `07350d4dd8b167c772f9ca145cd69b92ff0418632c2252d434b7d9ad59f6c244` |
| `tools/lint-core.mjs` | `255fb7c661ecb136911f8cb2c8dfd5d2fe69e3be89a4d53efd0b9e83d3c5f0d3` |
| `tools/metatest.mjs` | `705918246fe8ca85193a721152c8bb8029996c876be53b52ecfcc777647b7ab8` |
| `tools/preflight.mjs` | `9160836d5b92d234f4b85a37a192fb2e3c87e86123d53522cd73dd24caaf30e0` |
| `tools/README.md` | `4b5589338cf5b1b0a4403fe696e5f2e76bffc3608abf37a9b22b428e90903931` |
| `tools/report-logic.mjs` | `dc9444fed6d43b01b6155b622e15429d47d425666d30c429bc3fcf508413780a` |
| `tools/screen-files.mjs` | `d975c827273def112992f5ad6b1269817fffc6efc3e882a7d41d0d4269735e48` |
| `tools/selftest.mjs` | `7ed095f1245c507dbfce69014f517ed69009f5b7ffef764ba9ceac96f5c5db88` |
| `tools/spec-lint.mjs` | `520964df0ad36015cb3afce41ec8f89bd54dd6bb9d345ce47c7cd3da8075503d` |
| `tools/sync-icon-paths.mjs` | `7e8e9836aa79f545f95c381810df3a3fe68f607c652e36d6718d4e9f1f513de9` |
| `tools/test-generated.mjs` | `bc218b83578e5069cc94d40bbef74bac2134e71c6717441d19dcc568bb8d4ba4` |
| `tools/verify.mjs` | `c44a141766ac3b9b5b2a4e3aa178c2a8e038a69c2da2fe2c5a9839db830275fc` |

## Leveransytan utanför reporoten

| Fil | SHA-256 |
|---|---|
| `zip:/Butlery Fas 0 leverans.dc.html` | `cd3f24aacd6a45c4ec21cddd66f5aeeffec8badc0482f71277c61a2f26a8d97b` |
| `zip:/Butlery granskning och implementeringsplan.dc.html` | `76ab6fe3c1a833d5c2345b9391464de2446da52d7483e488facd5b38a05060fb` |
| `zip:/Butlery styrdokument modulart designsystem.dc.html` | `854b9a162f3fa09fdac3854ba774853ec2462b94f877f29052df93559ea5c0b7` |
| `zip:/fas0/DELIVERY` | `d9b3ef4a66ffc0c8ad97ac7dc80d0ec25cf19763c3448e1815cde9d6d935edd9` |
| `zip:/fas0/LAS-MIG.md` | `ff5c5a1b9fca4c05408fbd5937368bb5ff95832028bbc67a8a972239a1e3b87b` |
| `zip:/support.js` | `8fe7df74405f3c55f49b7249c74ea1397e65d07dea2b1bd3b4a489bec2e28cbe` |
| `zip:/uploads/Butlery-arbetsorder-modulart-designsystem.md` | `4606e0ba64e57025713d717ed2415a0fcb3d541a7f9b74f0ed570efd821bd52b` |
