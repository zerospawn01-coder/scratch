import { useStore } from '../state/worldStore';
import { useSVPSession } from '../session/svp';
import { useLedgerSession } from '../session/ledgerSession';
import Topology2DView from '../views/Topology2D/Topology2DView';
import Blast3DView from '../views/Blast3D/Blast3DView';

import RunbookPanel from '../components/RunbookPanel';
import AuditTicker from '../components/AuditTicker';
import DrainMonitor from '../components/DrainMonitor';
import ExecutionGateModal from '../ui/overlays/ExecutionGateModal';
import SilentCamera from '../ui/hud/SilentCamera';
import AudioControl from '../ui/hud/AudioControl';

const App = () => {
    const { nodes, edges, is3D, isSilent, lastCommand, isSafeMode } = useStore();
    const { connected } = useSVPSession();
    useLedgerSession(); // Bind SSE Ledger

    const statusText = connected ? 'CONNECTED' : 'DISCONNECTED';

    return (
        <div className={`topology-container ${is3D ? 'view-3d' : ''}`}>
            {/* HUD */}
            <div className="hud-overlay glass-panel">
                <div className={`svp-status ${!connected ? 'stalled' : ''}`}>
                    SVP: {statusText}
                    {!connected && <span className="reconnect-pulse"> [RECONNECTING...]</span>}
                    {isSafeMode && <div className="safe-mode-alert"> [SAFE_MODE_ISOLATED]</div>}
                </div>
                <div className="command-log">LAST: {lastCommand} {isSilent ? '(SILENT)' : ''}</div>
            </div>

            {/* Overlays & Panels */}
            <RunbookPanel />
            <AuditTicker />
            <DrainMonitor />
            <ExecutionGateModal />
            <SilentCamera />
            <AudioControl />

            {/* Primary View */}
            {is3D ? (
                <Blast3DView nodes={nodes} edges={edges} focusNode={nodes[0]} />
            ) : (
                <Topology2DView nodes={nodes} edges={edges} />
            )}
        </div>
    );
};

export default App;
