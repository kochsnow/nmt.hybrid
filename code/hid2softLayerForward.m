function [softmax_h, h2sInfo] = hid2softLayerForward(h_t, params, model, trainData, curMask, tgtPos)
%%%
%
% From lstm hidden state to softmax hidden state.
%
% Thang Luong @ 2015, <lmthang@stanford.edu>
%
%%% 
  h2sInfo = [];
  
  if params.softmaxDim || params.attnFunc %|| (params.posModel==3 && mod(tgtPos, 2)==0)
    if params.softmaxDim % softmax compression: f(W_h * h_t)
      h2sInfo.input = h_t;
    elseif params.attnFunc % attention mechanism: f(W_h*[attn_t; tgt_h_t]), attn_t is the context vector in the paper.
%       if params.predictPos % hard attention
%           % h_t -> h_pos
%           [h2sInfo.h_pos] = hiddenLayerForward(model.W_h_pos, h_t, params.nonlinear_f);
%           
%           % predict weight for the src hidden state: sigmoid(v_pos'*f(W_h*h_t))
%           alignScores = model.v_pos*h2sInfo.h_pos;
%           h2sInfo.alignWeights = params.nonlinear_gate_f(alignScores); % 1*batchSize
%           
%           % select alignment vector
%           [srcHidVecs, h2sInfo.linearIndices, h2sInfo.unmaskedIds] = buildSrcPosVecs(tgtPos, params, trainData, trainData.positions, curMask);
%           attnVecs = bsxfun(@times,h2sInfo.alignWeights, srcHidVecs);
%       else % soft attention
%       end
      
      if params.predictPos % use unsupervised alignments
        if params.oldSrcVecs % old
          [srcHidVecs, h2sInfo.linearIndices, h2sInfo.unmaskedIds, h2sInfo.attnLinearIndices] = buildSrcVecsOld(tgtPos, params, trainData, trainData.positions, curMask);
        else % new
          posFlags = curMask.mask & (trainData.positions~=params.nullPosId);
         
          % TODO move this code out
          if params.attnRelativePos
            srcPositions = tgtPos - (trainData.positions - params.zeroPosId); % src_pos = tgt_pos - relative_pos
          else % absolute position
            srcPositions = trainData.positions - params.zeroPosId;
          end
                
          % IMPORTANT: since source sentences are reversed we use srcMaxLen-srcPositions
          if params.isReverse
            srcPositions = trainData.srcMaxLen - srcPositions;
          end
          [srcHidVecs, h2sInfo.startAttnIds, h2sInfo.endAttnIds, h2sInfo.startIds, h2sInfo.endIds, h2sInfo.indices] = buildSrcVecs(trainData.srcHidVecs, srcPositions, posFlags, params);
          
          % assert
          if params.assert
            [srcHidVecs1] = buildSrcVecsOld(tgtPos, params, trainData, trainData.positions, curMask);
            assert(sum(sum(sum(abs(srcHidVecs-srcHidVecs1))))<1e-10);
          end
        end
        
      elseif params.attnRelativePos % relative (approximate aligned src position by tgtPos)
        [srcHidVecs, h2sInfo.startAttnId, h2sInfo.endAttnId, h2sInfo.startHidId, h2sInfo.endHidId] = buildSrcHidVecs(...
          trainData.srcHidVecs, trainData.srcMaxLen, tgtPos, params);
      else % absolute
        srcHidVecs = trainData.absSrcHidVecs;
      end   
      [attnVecs, h2sInfo.alignWeights] = attnLayerForward(model.W_a, h_t, srcHidVecs, curMask.mask);
      
%       if params.numAttnPositions>1  
%       else
%         attnVecs = bsxfun(@times, srcHidVecs, curMask.mask);
%         h2sInfo.alignWeights = ones(1, params.curBatchSize).*curMask.mask;
%       end
      
      % concat
      h2sInfo.input = [attnVecs; h_t];
      h2sInfo.h_t = h_t;
    end
    
    softmax_h = hiddenLayerForward(model.W_h, h2sInfo.input, params.nonlinear_f);
    h2sInfo.softmax_h = softmax_h;
  else % no intermediate layer
    softmax_h = h_t;
  end
end

%     elseif params.posModel==3 && mod(tgtPos, 2)==0 % positional model 3: f(W_h * [srcPosVecs; h_t])
%       if isTest==0
%         positions = trainData.tgtOutput(:, tgtPos-1)'; % Here we look at the previous time steps for positions
%       else
%         positions = trainData.positions;
%       end
%       
%       [srcHidVecs, h2sInfo.linearIndices] = buildSrcPosVecs(tgtPos, params, trainData, positions, curMask);
%       h2sInfo.input = [srcHidVecs; h_t];
    