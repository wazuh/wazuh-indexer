/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * The OpenSearch Contributors require contributions made to
 * this file be licensed under the Apache-2.0 license or a
 * compatible open source license.
 */

package org.opensearch.search.aggregations;

import org.apache.lucene.search.Collector;
import org.apache.lucene.search.CollectorManager;
import org.opensearch.search.internal.SearchContext;
import org.opensearch.search.profile.query.CollectorResult;

import java.io.IOException;
import java.util.Collections;
import java.util.Objects;

/**
 * {@link CollectorManager} to take care of non-global aggregation operators in case of concurrent segment search
 */
public class NonGlobalAggCollectorManager extends AggregationCollectorManager {

    private Collector collector;
    private final String collectorName;

    public NonGlobalAggCollectorManager(SearchContext context) throws IOException {
        super(context, context.aggregations().factories()::createTopLevelNonGlobalAggregators, CollectorResult.REASON_AGGREGATION);
        collector = Objects.requireNonNull(super.newCollector(), "collector instance is null");
        collectorName = collector.toString();
    }

    @Override
    public Collector newCollector() throws IOException {
        if (collector != null) {
            final Collector toReturn = collector;
            collector = null;
            return toReturn;
        } else {
            return super.newCollector();
        }
    }

    @Override
    protected AggregationReduceableSearchResult buildAggregationResult(InternalAggregations internalAggregations) {
        // Reduce the aggregations across slices before sending to the coordinator. We will perform shard level reduce as long as any slices
        // were created so that we can apply shard level bucket count thresholds in the reduce phase.
        return new AggregationReduceableSearchResult(
            // using topLevelReduce here as PipelineTreeSource needs to be sent to coordinator in older release of OpenSearch. The actual
            // evaluation of pipeline aggregation though happens on the coordinator during final reduction phase
            InternalAggregations.topLevelReduce(Collections.singletonList(internalAggregations), context.partialOnShard())
        );
    }

    @Override
    public String getCollectorName() {
        return collectorName;
    }
}
