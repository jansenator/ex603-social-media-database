# Task 4.1

The trust lead is the person who would act on the per-post breakdown. That is the person who decides which posts get a closer look before anyone touches creator monetization again.

The platform average dwell is 18,140.95 milliseconds. That one number covers 200 reactions whose dwell runs from 0 to 70,860 milliseconds, and 34 of those reactions are exactly 0. The count of 200 conceals who is counted. Post 6 accounts for 21 reactions. Posts 14 and 15 account for none. The 6 percent failure rate conceals the same kind of mix. Several of the busiest posts have no spam removals, and post 2 has three.

The next view is the individual spam-removal rows for the posts that sit well above the baseline, with the account that reacted and the time of the reaction, and a check on whether the zero-dwell reactions gather on a few posts.

# Task 4.2

## Part A

The conditional aggregation answers two questions side by side. How many reactions does each post have? How many of those reactions were removed as spam?

Post 2 has 16 reactions and 3 spam removals. Post 3 has 13 reactions and 2 spam removals. Those two are the outliers named in the finding.

## Part B

The regional director is the reader who needs subtotals. That director wants one row per viewer country, which is `client_country` on the reaction. The dataset has no column named region.

The five country rows are the subtotals: Brazil 3 of 39 (7.69 percent), India 4 of 40 (10.00 percent), the UK 1 of 40 (2.50 percent), the US 3 of 38 (7.89 percent), and Vietnam 1 of 43 (2.33 percent). The grand total is the one row labeled Platform total: 200 reactions, 12 spam removals, 6.00 percent. `GROUPING` is 1 on that row and 0 on each country row.

A country row tells the director how viewers in that country compare with viewers in the others. It does not say what the platform rate is, and it does not say whether that country is large enough to move the platform rate. The grand total is the figure behind the monetization decision. With every viewer country included, the platform failure rate is 6 percent.

## Part C

The pipeline answers one question. What failure rate should a post with at least 10 reactions be compared against?

Twelve posts clear that line. Together they have 194 reactions and 11 spam removals. The pooled failure rate is 5.67 percent. That is the baseline in the finding. An average of the twelve separate rates is 6.07 percent. The average gives a post with 11 reactions the same weight as a post with 21. The pooled rate weights each reaction equally.

# Reflection

Conditional aggregation computes the reaction count and the spam-removal count in one read of the log. For each reaction the query adds one to the reaction total, and it adds one to the spam total only when that same row is a spam removal. Both numbers come from the rows the query is already holding.

Two separate filtered queries split that work. One query counts every reaction on the post. A second query keeps only the spam removals and counts those. Each statement walks the table on its own. On 200 rows the second walk costs little. At a million rows it is a second pass over the same pages, twice the reading, and twice as long as the table stays in the working set. The two statements also run at two moments. A reaction inserted, deleted, or reclassified between them changes one total and leaves the other as it was. The rate is then a mix of two populations, and a payout decision made from it is a decision about a set of rows that never existed together.

One pass closes that gap. The numerator and the denominator are counted from the same rows at the same time, and the rate is a division of those two totals. At a million rows that is the difference between one consistent answer and two answers that can drift apart.
