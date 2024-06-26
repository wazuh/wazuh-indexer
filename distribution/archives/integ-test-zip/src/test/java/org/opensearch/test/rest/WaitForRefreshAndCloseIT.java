/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * The OpenSearch Contributors require contributions made to
 * this file be licensed under the Apache-2.0 license or a
 * compatible open source license.
 */

/*
 * Licensed to Elasticsearch under one or more contributor
 * license agreements. See the NOTICE file distributed with
 * this work for additional information regarding copyright
 * ownership. Elasticsearch licenses this file to you under
 * the Apache License, Version 2.0 (the "License"); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

/*
 * Modifications Copyright OpenSearch Contributors. See
 * GitHub history for details.
 */

package org.opensearch.test.rest;

import org.opensearch.common.action.ActionFuture;
import org.apache.http.util.EntityUtils;
import org.opensearch.action.support.PlainActionFuture;
import org.opensearch.client.Request;
import org.opensearch.client.Response;
import org.opensearch.client.ResponseException;
import org.opensearch.client.ResponseListener;
import org.junit.After;
import org.junit.Before;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.instanceOf;

/**
 * Tests that wait for refresh is fired if the index is closed.
 */
public class WaitForRefreshAndCloseIT extends OpenSearchRestTestCase {
    @Before
    public void setupIndex() throws IOException {
        Request request = new Request("PUT", "/test");
        request.setJsonEntity("{\"settings\":{\"refresh_interval\":-1}}");
        client().performRequest(request);
    }

    @After
    public void cleanupIndex() throws IOException {
        client().performRequest(new Request("DELETE", "/test"));
    }

    private String docPath() {
        return "test/_doc/1";
    }

    public void testIndexAndThenClose() throws Exception {
        Request request = new Request("PUT", docPath());
        request.setJsonEntity("{\"test\":\"test\"}");
        closeWhileListenerEngaged(start(request));
    }

    public void testUpdateAndThenClose() throws Exception {
        Request createDoc = new Request("PUT", docPath());
        createDoc.setJsonEntity("{\"test\":\"test\"}");
        client().performRequest(createDoc);
        Request updateDoc = new Request("POST", "test/_update/1");
        updateDoc.setJsonEntity("{\"doc\":{\"name\":\"test\"}}");
        closeWhileListenerEngaged(start(updateDoc));
    }

    public void testDeleteAndThenClose() throws Exception {
        Request request = new Request("PUT", docPath());
        request.setJsonEntity("{\"test\":\"test\"}");
        client().performRequest(request);
        closeWhileListenerEngaged(start(new Request("DELETE", docPath())));
    }

    private void closeWhileListenerEngaged(ActionFuture<String> future) throws Exception {
        // Wait for the refresh listener to start waiting
        assertBusy(() -> {
            Map<String, Object> stats;
            try {
                stats = entityAsMap(client().performRequest(new Request("GET", "/test/_stats/refresh")));
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
            Map<?, ?> indices = (Map<?, ?>) stats.get("indices");
            Map<?, ?> theIndex = (Map<?, ?>) indices.get("test");
            Map<?, ?> total = (Map<?, ?>) theIndex.get("total");
            Map<?, ?> refresh = (Map<?, ?>) total.get("refresh");
            int listeners = (Integer) refresh.get("listeners");
            assertEquals(1, listeners);
        });

        // Close the index. That should flush the listener.
        client().performRequest(new Request("POST", "/test/_close"));

        /*
         * The request may fail, but we really, really, really want to make
         * sure that it doesn't time out.
         */
        try {
            future.get(1, TimeUnit.MINUTES);
        } catch (ExecutionException ee) {
            /*
             * If it *does* fail it should fail with a FORBIDDEN error because
             * it attempts to take an action on a closed index. Again, it'd be
             * nice if all requests waiting for refresh came back even though
             * the index is closed and most do, but sometimes they bump into
             * the index being closed. At least they don't hang forever. That'd
             * be a nightmare.
             */
            assertThat(ee.getCause(), instanceOf(ResponseException.class));
            ResponseException re = (ResponseException) ee.getCause();
            assertEquals(403, re.getResponse().getStatusLine().getStatusCode());
            assertThat(EntityUtils.toString(re.getResponse().getEntity()), containsString("FORBIDDEN/4/index closed"));
        }
    }

    private ActionFuture<String> start(Request request) {
        PlainActionFuture<String> future = new PlainActionFuture<>();
        request.addParameter("refresh", "wait_for");
        request.addParameter("error_trace", "");
        client().performRequestAsync(request, new ResponseListener() {
            @Override
            public void onSuccess(Response response) {
                try {
                    future.onResponse(EntityUtils.toString(response.getEntity()));
                } catch (IOException e) {
                    future.onFailure(e);
                }
            }

            @Override
            public void onFailure(Exception exception) {
                future.onFailure(exception);
            }
        });
        return future;
    }
}
