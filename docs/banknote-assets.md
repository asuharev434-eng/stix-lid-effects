# Banknote image sources

Downloaded on 2026-10-31 from official banknote information pages:

- Bank of Russia: https://www.cbr.ru/cash_circulation/banknotes/5000rub/?tab.current=y2010
- U.S. Currency Education Program: https://www.uscurrency.gov/denominations/100

The original downloaded JPEG files are stored unchanged in `Sources/MacDuo/Resources/Banknotes/`. The dollar images include the source's SPECIMEN markings, which are retained. No marks are removed and no details are retouched. Runtime decoding converts the images to RGBA8 for Metal; each pair uses its source aspect ratio. Images are bundled for offline use, with no runtime network requests.

These third-party banknote images are not original STIX illustrations and are not relicensed under the source-code license. Source attribution is retained here and in NOTICE.

## Files and integrity

### rubles-front.jpg

Source: https://www.cbr.ru/StaticHtml/File/96700/5000r_10_av.jpg

SHA-256: `0e72d4b11b420e3c16a330236a0d1d2954e37d494de31878744a7278a986c427`

### rubles-back.jpg

Source: https://www.cbr.ru/StaticHtml/File/96700/5000r_10_rv.jpg

SHA-256: `975593f7eecda8f58e7967e29743c21d4ceb8101a1b29b878335dea6596d30dd`

### dollars-front.jpg

Source: https://www.uscurrency.gov/sites/default/files/styles/bill_version/public/denominations/100-front-2013-present.jpg.jpg?itok=tVYD2VJT

SHA-256: `f9d085a00b5150b192c9a2e38b9cddc1186b49a2a66fb21e2af7a4db63b56004`

### dollars-back.jpg

Source: https://www.uscurrency.gov/sites/default/files/styles/bill_version/public/denominations/100-back-2013-present.jpg.jpg?itok=YbrfkL4e

SHA-256: `ec97eb99fdfca9756c730400dbe9df965086351169b58334af0be08a66ca9dfb`

